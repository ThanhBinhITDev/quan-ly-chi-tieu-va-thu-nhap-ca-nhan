import { Inject, Injectable } from '@nestjs/common';
import { SignJWT } from 'jose';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';

interface UserRow {
  id: string;
  email: string | null;
  phone: string | null;
  display_name: string;
}

export interface DevLoginResult {
  access_token: string;
  token_type: 'bearer';
  expires_in: number;
  user: {
    id: string;
    email: string | null;
    display_name: string;
  };
  /** Cờ để client biết đây không phải phiên Supabase thật. */
  dev_mode: true;
}

const TOKEN_TTL_SECONDS = 60 * 60 * 12;

/**
 * Phát JWT cho môi trường phát triển, ký bằng `SUPABASE_JWT_SECRET`.
 *
 * Đây KHÔNG phải hệ thống xác thực: mật khẩu là một chuỗi dùng chung lấy từ
 * biến môi trường, không kiểm với Supabase Auth. Nó chỉ tồn tại để kiểm thử
 * luồng đăng nhập thật của app khi máy dev chưa có anon key Supabase.
 *
 * Ba chốt an toàn, thiếu bất kỳ chốt nào là từ chối:
 *   1. `NODE_ENV !== 'production'`
 *   2. `DEV_LOGIN_PASSWORD` có giá trị và dài ≥ 12 ký tự
 *   3. `SUPABASE_JWT_SECRET` có giá trị (nếu không thì không ký được token)
 *
 * Khi bị tắt, endpoint trả `NOT_FOUND` chứ không trả 403: không xác nhận cho
 * người dò biết endpoint tồn tại.
 */
@Injectable()
export class DevLoginService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  private get password(): string {
    return process.env.DEV_LOGIN_PASSWORD ?? '';
  }

  private assertEnabled(): void {
    const disabled =
      process.env.NODE_ENV === 'production' ||
      this.password.length < 12 ||
      !process.env.SUPABASE_JWT_SECRET;
    if (disabled) {
      throw new ApiError('NOT_FOUND', 'Không tìm thấy tài nguyên');
    }
  }

  async login(email: string, password: string): Promise<DevLoginResult> {
    this.assertEnabled();

    if (!timingSafeEqual(password, this.password)) {
      // Thông báo giống hệt trường hợp sai email: không cho dò tài khoản.
      throw new ApiError('UNAUTHENTICATED', 'Email hoặc mật khẩu không đúng');
    }

    const row = await this.db.one<UserRow>(
      `SELECT id, email, phone, display_name
         FROM users
        WHERE email = $1 AND deleted_at IS NULL`,
      [email.toLowerCase()],
    );
    if (!row) {
      throw new ApiError('UNAUTHENTICATED', 'Email hoặc mật khẩu không đúng');
    }

    const token = await this.mint(row);

    return {
      access_token: token,
      token_type: 'bearer',
      expires_in: TOKEN_TTL_SECONDS,
      user: {
        id: row.id,
        email: row.email,
        display_name: row.display_name,
      },
      dev_mode: true,
    };
  }

  private async mint(row: UserRow): Promise<string> {
    const secret = process.env.SUPABASE_JWT_SECRET;
    if (!secret) {
      // assertEnabled đã chặn; giữ lại để TypeScript biết secret không null.
      throw new ApiError('NOT_FOUND', 'Không tìm thấy tài nguyên');
    }
    const now = Math.floor(Date.now() / 1000);
    return new SignJWT({
      sub: row.id,
      email: row.email ?? undefined,
      phone: row.phone ?? undefined,
      role: 'authenticated',
      aud: 'authenticated',
    })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuedAt(now)
      .setExpirationTime(now + TOKEN_TTL_SECONDS)
      .sign(new TextEncoder().encode(secret));
  }
}

/**
 * So sánh chuỗi không rò rỉ thời gian theo độ dài khớp.
 *
 * `===` dừng ở ký tự đầu khác nhau, nên thời gian phản hồi tiết lộ bao nhiêu
 * ký tự đã đúng. Với mật khẩu dùng chung điều này ít nguy hiểm hơn so với mật
 * khẩu người dùng, nhưng vẫn không nên để lộ.
 */
function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i];
  return diff === 0;
}
