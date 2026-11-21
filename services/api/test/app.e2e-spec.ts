import { createHmac } from 'node:crypto';

import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types.js';

import { AppModule } from './../src/app.module.js';
import { DATABASE } from './../src/common/db/database.js';
import { ApiExceptionFilter } from './../src/common/errors/api-exception.filter.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';
const WALLET = '22222222-2222-4222-8222-222222222222';
const OTHER_WALLET = '33333333-3333-4333-8333-333333333333';
const CATEGORY = 'aaaa1111-1111-4111-8111-111111111111';

/** Dòng ví như `WalletsService.COLUMNS` trả về (đã có `balance`). */
function walletRow(overrides: Record<string, unknown> = {}) {
  return {
    id: WALLET,
    name: 'Tiền mặt',
    type: 'cash',
    initial_balance: '0',
    balance: '0',
    color: null,
    icon: null,
    is_archived: false,
    rev: 1,
    deleted_at: null,
    ...overrides,
  };
}

const TEST_SECRET = 'test-secret-khong-dung-production';

/** Ký JWT HS256 thật để API phải xác thực chữ ký như production. */
function signToken(
  // Supabase luôn kèm email hoặc phone trong token; API dựa vào đó để tạo
  // hồ sơ (`users_contact` yêu cầu ít nhất một trong hai).
  payload: Record<string, unknown> = {
    sub: USER,
    role: 'authenticated',
    email: 'binh@example.com',
  },
  secret: string = TEST_SECRET,
): string {
  const enc = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  const header = enc({ alg: 'HS256', typ: 'JWT' });
  const body = enc(payload);
  const signature = createHmac('sha256', secret)
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${signature}`;
}

const devToken = (): string => signToken();

describe('API (e2e)', () => {
  let app: INestApplication<App>;
  let db: FakeDatabase;

  beforeEach(async () => {
    process.env.SUPABASE_JWT_SECRET = TEST_SECRET;
    db = new FakeDatabase().on('SELECT 1 AS ok', [{ ok: 1 }]);

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(DATABASE)
      .useValue(db)
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    app.useGlobalFilters(new ApiExceptionFilter());
    await app.init();
  });

  afterEach(async () => {
    await app.close();
    delete process.env.SUPABASE_JWT_SECRET;
  });

  it('GET /health báo database hoạt động', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.body).toMatchObject({ status: 'ok', database: 'up' });
  });

  it('thiếu token thì trả UNAUTHENTICATED', async () => {
    const res = await request(app.getHttpServer())
      .get('/v1/wallets')
      .expect(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('sai DTO thì trả VALIDATION_FAILED', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/wallets')
      .set('Authorization', `Bearer ${devToken()}`)
      .send({ id: WALLET, name: 'Ví', type: 'khong-hop-le' })
      .expect(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
  });

  it('tạo ví hợp lệ với token hợp lệ', async () => {
    db.on('SELECT id, user_id FROM wallets WHERE id', [])
      .on('count(*)', [{ count: '0' }])
      .on('INSERT INTO wallets', [])
      .on('FROM wallets w', [walletRow()]);

    const res = await request(app.getHttpServer())
      .post('/v1/wallets')
      .set('Authorization', `Bearer ${devToken()}`)
      .send({ id: WALLET, name: 'Tiền mặt', type: 'cash' })
      .expect(201);

    expect(res.body).toMatchObject({
      id: WALLET,
      name: 'Tiền mặt',
      balance: 0,
    });
  });

  it('GET /v1/wallets trả số dư tính từ giao dịch', async () => {
    db.on('FROM wallets w', [
      walletRow({ id: WALLET, balance: '1700000' }),
      walletRow({ id: OTHER_WALLET, type: 'bank', balance: '-100000' }),
    ]);

    const res = await request(app.getHttpServer())
      .get('/v1/wallets')
      .set('Authorization', `Bearer ${devToken()}`)
      .expect(200);

    expect(res.body).toHaveLength(2);
    expect(res.body[0]).toMatchObject({ id: WALLET, balance: 1_700_000 });
    // Truy vấn phải lọc ví đã xoá mềm.
    expect(db.lastSql).toContain('deleted_at IS NULL');
  });

  it('GET /v1/wallets/summary tổng hợp số dư theo ví và loại', async () => {
    db.on('FROM wallets w', [
      walletRow({ id: WALLET, type: 'cash', balance: '150000' }),
      walletRow({ id: OTHER_WALLET, type: 'bank', balance: '-50000' }),
    ]);

    const res = await request(app.getHttpServer())
      .get('/v1/wallets/summary')
      .set('Authorization', `Bearer ${devToken()}`)
      .expect(200);

    expect(res.body.total_balance).toBe(100000);
    expect(res.body.by_type).toEqual({ cash: 150000, bank: -50000 });
    expect(res.body.wallets).toHaveLength(2);
  });

  it('DELETE /v1/wallets/:id xoá mềm và trả deleted_at', async () => {
    // Đọc lần 1 thấy ví còn sống (rev 1), sau UPDATE đọc lại thấy bản đã xoá.
    db.query = async <T,>(sql: string) => {
      db.executed.push(sql);
      if (sql.includes('UPDATE wallets')) return [] as T[];
      if (sql.includes('FROM wallets w')) {
        return [
          sql.includes('w.deleted_at IS NULL')
            ? walletRow({ rev: 1 })
            : walletRow({ rev: 2, deleted_at: '2026-11-20T00:00:00.000Z' }),
        ] as T[];
      }
      return [] as T[];
    };

    const res = await request(app.getHttpServer())
      .delete(`/v1/wallets/${WALLET}?rev=2`)
      .set('Authorization', `Bearer ${devToken()}`)
      .expect(200);

    expect(res.body.deleted_at).toBe('2026-11-20T00:00:00.000Z');
    expect(db.executed.some((sql) => sql.includes('deleted_at = now()'))).toBe(
      true,
    );
  });

  it('DELETE /v1/categories/:id xoá mềm danh mục của mình', async () => {
    const categoryRow = (rev: number, deletedAt: string | null) => ({
      id: CATEGORY,
      user_id: USER,
      name: 'Cà phê',
      type: 'expense',
      icon: null,
      color: null,
      parent_id: null,
      is_system: false,
      sort_order: 0,
      rev,
      deleted_at: deletedAt,
    });
    db.query = async <T,>(sql: string) => {
      db.executed.push(sql);
      if (sql.includes('UPDATE categories')) return [] as T[];
      if (sql.includes('FROM categories')) {
        return [
          sql.includes('deleted_at IS NULL')
            ? categoryRow(1, null)
            : categoryRow(2, '2026-11-20T00:00:00.000Z'),
        ] as T[];
      }
      return [] as T[];
    };

    const res = await request(app.getHttpServer())
      .delete(`/v1/categories/${CATEGORY}?rev=2`)
      .set('Authorization', `Bearer ${devToken()}`)
      .expect(200);

    expect(res.body.deleted_at).toBe('2026-11-20T00:00:00.000Z');
  });

  it('báo cáo tháng trả công thức daily_limit đúng', async () => {
    db.on('SUM(amount) FILTER', [{ income: '5000000', expense: '1500000' }])
      .on('FROM budgets', [{ amount: '3000000' }])
      .on('GROUP BY c.id', [])
      .on('GROUP BY occurred_on', []);

    const res = await request(app.getHttpServer())
      .get('/v1/reports/month-summary?year=2026&month=11')
      .set('Authorization', `Bearer ${devToken()}`)
      .expect(200);

    expect(res.body.expense).toBe(1_500_000);
    expect(res.body.budget.total).toBe(3_000_000);
    expect(res.body.remaining).toBe(1_500_000);
    expect(res.body.period.start).toBe('2026-11-01');
    expect(res.body.period.end).toBe('2026-11-30');
    // floor(1_500_000 / days_left), days_left >= 1 luôn đúng
    expect(res.body.daily_limit).toBeLessThanOrEqual(1_500_000);
    expect(Number.isInteger(res.body.daily_limit)).toBe(true);
  });

  it('GET /v1/me tạo hồ sơ khi chưa có', async () => {
    db.on('SELECT id, email, phone', [])
      .on('INSERT INTO users', [
        {
          id: USER,
          email: 'binh@example.com',
          phone: null,
          display_name: 'binh',
          plan: 'free',
          plan_expires_at: null,
          currency: 'VND',
          timezone: 'Asia/Ho_Chi_Minh',
          onboarded_at: null,
          created_at: '2026-11-19T00:00:00.000Z',
        },
      ]);

    const res = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${devToken()}`)
      .expect(200);

    expect(res.body).toMatchObject({ id: USER, display_name: 'binh' });
  });

  it('GET /v1/budgets/progress không bị hiểu là :id', async () => {
    db.on('FROM budgets b', []).on('SELECT category_id, SUM(amount)', []);

    const res = await request(app.getHttpServer())
      .get('/v1/budgets/progress')
      .set('Authorization', `Bearer ${devToken()}`)
      .expect(200);

    expect(res.body.items).toEqual([]);
    expect(res.body.as_of).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('POST /v1/goals chặn target_amount <= 0', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/goals')
      .set('Authorization', `Bearer ${devToken()}`)
      .send({
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        name: 'Mua laptop',
        target_amount: 0,
      })
      .expect(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
  });
});
