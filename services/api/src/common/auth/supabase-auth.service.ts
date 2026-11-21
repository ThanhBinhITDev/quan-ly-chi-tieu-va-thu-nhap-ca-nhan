import { Injectable } from '@nestjs/common';
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';

export interface AuthUser {
  id: string;
  email?: string;
  phone?: string;
  role?: string;
}

/**
 * Xác thực Bearer JWT do Supabase Auth phát hành.
 *
 * - Ưu tiên `SUPABASE_JWT_SECRET` (HS256) khi chạy local/self-host
 * - Nếu không, xác thực chữ ký qua JWKS: `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`
 * - Không cấu hình cả hai: **từ chối mọi token**. Không có chế độ "bỏ qua
 *   chữ ký" nào, kể cả khi đặt biến môi trường.
 *
 * Server không bao giờ tin `user_id` do client gửi; luôn lấy từ `sub` của token.
 */
@Injectable()
export class SupabaseAuthService {
  private jwks: ReturnType<typeof createRemoteJWKSet> | null = null;

  constructor() {
    const supabaseUrl = process.env.SUPABASE_URL;
    if (supabaseUrl) {
      this.jwks = createRemoteJWKSet(
        new URL('/auth/v1/.well-known/jwks.json', supabaseUrl),
      );
    }
  }

  async verify(token: string): Promise<AuthUser> {
    const payload = await this.verifySignature(token);
    const sub = payload.sub;
    if (typeof sub !== 'string' || sub.length === 0) {
      throw new Error('Token không có sub');
    }
    return {
      id: sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
      phone: typeof payload.phone === 'string' ? payload.phone : undefined,
      role: typeof payload.role === 'string' ? payload.role : undefined,
    };
  }

  private async verifySignature(token: string): Promise<JWTPayload> {
    const secret = process.env.SUPABASE_JWT_SECRET;
    if (secret) {
      const { payload } = await jwtVerify(
        token,
        new TextEncoder().encode(secret),
        { algorithms: ['HS256'] },
      );
      return payload;
    }
    if (this.jwks) {
      const { payload } = await jwtVerify(token, this.jwks);
      return payload;
    }
    // Không có cách xác thực nào: từ chối, không đoán payload.
    // (Trước đây có nhánh AUTH_ALLOW_UNVERIFIED đọc payload mà không kiểm
    // chữ ký, khiến token ký bằng bất kỳ secret nào cũng qua được — đã bỏ.)
    throw new Error('Chưa cấu hình SUPABASE_URL hoặc SUPABASE_JWT_SECRET');
  }
}
