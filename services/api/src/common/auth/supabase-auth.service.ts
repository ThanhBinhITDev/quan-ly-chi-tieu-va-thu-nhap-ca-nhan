import { Injectable, Logger } from '@nestjs/common';
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';

export interface AuthUser {
  id: string;
  email?: string;
  role?: string;
}

/**
 * Xác thực Bearer JWT do Supabase Auth phát hành.
 *
 * - Ưu tiên xác thực chữ ký qua JWKS: `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`
 * - Hỗ trợ `SUPABASE_JWT_SECRET` (HS256) cho môi trường local/self-host
 * - Nếu chưa cấu hình gì, chỉ chấp nhận ở chế độ dev (`AUTH_ALLOW_UNVERIFIED=true`)
 *   để không vô tình mở API ở production.
 *
 * Server không bao giờ tin `user_id` do client gửi; luôn lấy từ `sub` của token.
 */
@Injectable()
export class SupabaseAuthService {
  private readonly logger = new Logger(SupabaseAuthService.name);
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
      role: typeof payload.role === 'string' ? payload.role : undefined,
    };
  }

  private async verifySignature(token: string): Promise<JWTPayload> {
    const secret = process.env.SUPABASE_JWT_SECRET;
    if (secret) {
      const { payload } = await jwtVerify(
        token,
        new TextEncoder().encode(secret),
      );
      return payload;
    }
    if (this.jwks) {
      const { payload } = await jwtVerify(token, this.jwks);
      return payload;
    }
    if (process.env.AUTH_ALLOW_UNVERIFIED === 'true') {
      this.logger.warn(
        'AUTH_ALLOW_UNVERIFIED=true: chỉ dùng cho phát triển, không dùng ở production.',
      );
      const { payload } = await jwtVerify(token, new TextEncoder().encode('dev'), {
        algorithms: ['HS256'],
      }).catch(() => {
        // Không xác thực được chữ ký: đọc payload để test local.
        const parts = token.split('.');
        if (parts.length !== 3) throw new Error('Token không hợp lệ');
        return {
          payload: JSON.parse(
            Buffer.from(parts[1], 'base64url').toString('utf8'),
          ) as JWTPayload,
        };
      });
      return payload;
    }
    throw new Error('Chưa cấu hình SUPABASE_URL hoặc SUPABASE_JWT_SECRET');
  }
}
