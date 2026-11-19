import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';

import { SupabaseAuthService, type AuthUser } from './supabase-auth.service.js';

export interface AuthedRequest extends Request {
  user: AuthUser;
}

/** Bắt buộc có Bearer token hợp lệ; gắn user vào request. */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly auth: SupabaseAuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Thiếu token');
    }
    try {
      request.user = await this.auth.verify(header.slice(7).trim());
      return true;
    } catch {
      throw new UnauthorizedException('Token không hợp lệ hoặc đã hết hạn');
    }
  }
}
