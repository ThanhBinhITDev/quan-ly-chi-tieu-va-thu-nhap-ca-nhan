import { Global, Module } from '@nestjs/common';

import { AuthGuard } from './auth.guard.js';
import { SupabaseAuthService } from './supabase-auth.service.js';

@Global()
@Module({
  providers: [SupabaseAuthService, AuthGuard],
  exports: [SupabaseAuthService, AuthGuard],
})
export class AuthModule {}
