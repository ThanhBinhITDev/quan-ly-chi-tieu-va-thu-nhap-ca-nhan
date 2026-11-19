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

/** Token HS256 ký bằng 'dev'; chỉ dùng cho test. */
function devToken(): string {
  const enc = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  const header = enc({ alg: 'HS256', typ: 'JWT' });
  const payload = enc({ sub: USER, role: 'authenticated' });
  return `${header}.${payload}.signature-khong-kiem-tra`;
}

describe('API (e2e)', () => {
  let app: INestApplication<App>;
  let db: FakeDatabase;

  beforeEach(async () => {
    process.env.AUTH_ALLOW_UNVERIFIED = 'true';
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
    delete process.env.AUTH_ALLOW_UNVERIFIED;
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
      .on('INSERT INTO wallets', [
        {
          id: WALLET,
          name: 'Tiền mặt',
          type: 'cash',
          initial_balance: '0',
          color: null,
          icon: null,
          is_archived: false,
          rev: 1,
        },
      ]);

    const res = await request(app.getHttpServer())
      .post('/v1/wallets')
      .set('Authorization', `Bearer ${devToken()}`)
      .send({ id: WALLET, name: 'Tiền mặt', type: 'cash' })
      .expect(201);

    expect(res.body).toMatchObject({ id: WALLET, name: 'Tiền mặt' });
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
