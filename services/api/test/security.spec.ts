import { createHmac } from 'node:crypto';

import { ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import type { App } from 'supertest/types.js';

import { AppModule } from './../src/app.module.js';
import { DATABASE } from './../src/common/db/database.js';
import { ApiExceptionFilter } from './../src/common/errors/api-exception.filter.js';
import { SupabaseAuthService } from './../src/common/auth/supabase-auth.service.js';
import { FakeDatabase } from './fake-database.js';

const SECRET = 'security-spec-secret';
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '99999999-9999-4999-8999-999999999999';

function sign(
  payload: Record<string, unknown>,
  secret: string | null = SECRET,
): string {
  const enc = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  const header = enc({ alg: 'HS256', typ: 'JWT' });
  const body = enc(payload);
  if (secret === null) return `${header}.${body}.`;
  const signature = createHmac('sha256', secret)
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${signature}`;
}

// Có email: `users_contact` bắt buộc email hoặc phone khi tạo hồ sơ, nếu
// thiếu cả hai API trả VALIDATION_FAILED (đúng thiết kế, xem BUG-1).
const validToken = (): string =>
  sign({ sub: USER, role: 'authenticated', email: 'a@example.com' });

/**
 * Nhóm test chống hồi quy cho các lỗ hổng đã tìm thấy khi audit API.
 * Mỗi test tương ứng một lỗi thật từng tồn tại trong code.
 */
describe('Bảo mật API', () => {
  let app: INestApplication<App>;
  const originalSecret = process.env.SUPABASE_JWT_SECRET;
  const originalAllow = process.env.AUTH_ALLOW_UNVERIFIED;

  beforeEach(async () => {
    process.env.SUPABASE_JWT_SECRET = SECRET;
    delete process.env.SUPABASE_URL;
    // Cờ cũ từng mở đường bỏ qua chữ ký; đặt lại để chắc nó không còn tác dụng.
    process.env.AUTH_ALLOW_UNVERIFIED = 'true';

    // `/v1/me` cần một hồ sơ có sẵn để trả 200 thay vì đi vào nhánh INSERT.
    const meRow = {
      id: USER,
      email: 'a@example.com',
      phone: null,
      display_name: 'Binh Test',
      plan: 'free',
      plan_expires_at: null,
      currency: 'VND',
      timezone: 'Asia/Ho_Chi_Minh',
      onboarded_at: null,
      created_at: '2026-11-01T00:00:00.000Z',
    };
    const db = new FakeDatabase()
      .on('SELECT 1 AS ok', [{ ok: 1 }])
      .on('FROM users WHERE id = $1 AND deleted_at IS NULL', [meRow]);
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
    if (originalSecret === undefined) delete process.env.SUPABASE_JWT_SECRET;
    else process.env.SUPABASE_JWT_SECRET = originalSecret;
    if (originalAllow === undefined) delete process.env.AUTH_ALLOW_UNVERIFIED;
    else process.env.AUTH_ALLOW_UNVERIFIED = originalAllow;
  });

  describe('AUTH-1: không chấp nhận token không xác thực', () => {
    it('từ chối token ký bằng secret khác', async () => {
      const forged = sign({ sub: USER, role: 'authenticated' }, 'attacker-secret');
      await request(app.getHttpServer())
        .get('/v1/me')
        .set('Authorization', `Bearer ${forged}`)
        .expect(401);
    });

    it('từ chối token alg:none', async () => {
      const header = Buffer.from(
        JSON.stringify({ alg: 'none', typ: 'JWT' }),
      ).toString('base64url');
      const body = Buffer.from(
        JSON.stringify({ sub: USER, role: 'authenticated' }),
      ).toString('base64url');
      await request(app.getHttpServer())
        .get('/v1/me')
        .set('Authorization', `Bearer ${header}.${body}.`)
        .expect(401);
    });

    it('từ chối token đã hết hạn dù chữ ký đúng', async () => {
      const expired = sign({
        sub: USER,
        role: 'authenticated',
        exp: Math.floor(Date.now() / 1000) - 60,
      });
      await request(app.getHttpServer())
        .get('/v1/me')
        .set('Authorization', `Bearer ${expired}`)
        .expect(401);
    });

    it('vẫn nhận token hợp lệ khi cờ AUTH_ALLOW_UNVERIFIED đang bật', async () => {
      await request(app.getHttpServer())
        .get('/v1/me')
        .set('Authorization', `Bearer ${validToken()}`)
        .expect(200);
    });

    it('không cấu hình secret thì từ chối, không đoán payload', async () => {
      delete process.env.SUPABASE_JWT_SECRET;
      await request(app.getHttpServer())
        .get('/v1/me')
        .set('Authorization', `Bearer ${validToken()}`)
        .expect(401);
    });
  });

  describe('AUTH-2: thiếu header hoặc định dạng sai', () => {
    it.each([
      ['không có header', undefined],
      ['token rỗng', 'Bearer '],
      ['không phải Bearer', 'Basic YWJjOmRlZg=='],
      ['chuỗi rác', 'Bearer khong-phai-jwt'],
    ])('%s → 401', async (_label, header) => {
      const req = request(app.getHttpServer()).get('/v1/wallets');
      if (header) req.set('Authorization', header);
      await req.expect(401);
    });
  });

  describe('AUTHZ-1: người dùng không tự nâng gói', () => {
    it('PATCH /v1/me từ chối trường plan', async () => {
      const res = await request(app.getHttpServer())
        .patch('/v1/me')
        .set('Authorization', `Bearer ${validToken()}`)
        .send({ plan: 'pro_year' })
        .expect(400);
      expect(JSON.stringify(res.body)).toContain('VALIDATION_FAILED');
    });

    it('UpdateMeDto không còn khai báo plan', async () => {
      const { UpdateMeDto } = await import('./../src/modules/auth/me.dto.js');
      const dto = new UpdateMeDto();
      expect('plan' in dto).toBe(false);
    });
  });

  describe('AuthService: chọn đúng cách xác thực', () => {
    it('ưu tiên secret chia sẻ hơn JWKS', () => {
      const service = new SupabaseAuthService();
      // Không ném lỗi khi có secret; xác thực qua được token đúng.
      return expect(
        service.verify(validToken()),
      ).resolves.toMatchObject({ id: USER });
    });

    it('bỏ qua cờ AUTH_ALLOW_UNVERIFIED', () => {
      process.env.AUTH_ALLOW_UNVERIFIED = 'true';
      const service = new SupabaseAuthService();
      return expect(
        service.verify(sign({ sub: OTHER }, 'attacker-secret')),
      ).rejects.toBeTruthy();
    });
  });
});
