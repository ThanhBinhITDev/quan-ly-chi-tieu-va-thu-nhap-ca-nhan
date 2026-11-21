import { Body, Controller, Post } from '@nestjs/common';
import { IsEmail, IsOptional, IsString, Length, MinLength } from 'class-validator';

import { DevLoginService } from './dev-login.service.js';

export class DevLoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(1)
  password!: string;
}

export class DevRegisterDto extends DevLoginDto {
  @IsOptional()
  @IsString()
  @Length(0, 80)
  display_name?: string;
}

/**
 * Đăng nhập cho môi trường phát triển.
 *
 * Vì sao tồn tại: API xác thực JWT bằng `SUPABASE_JWT_SECRET`, nhưng máy dev
 * không có anon key của Supabase nên app không gọi được Supabase Auth. Không
 * có endpoint này thì chỉ còn cách nhét token bằng `--dart-define`, tức là
 * không kiểm được form đăng nhập thật.
 *
 * Chốt an toàn (xem `DevLoginService.assertEnabled`): tắt hoàn toàn khi
 * `NODE_ENV=production`, và chỉ bật khi có `DEV_LOGIN_PASSWORD`.
 */
@Controller('v1/dev')
export class DevLoginController {
  constructor(private readonly devLogin: DevLoginService) {}

  @Post('login')
  login(@Body() dto: DevLoginDto) {
    return this.devLogin.login(dto.email, dto.password);
  }

  /**
   * Tạo tài khoản local để thử luồng đăng ký. Không có trên Supabase Auth:
   * màn đăng ký thật đi qua `/auth/v1/signup` của Supabase.
   */
  @Post('register')
  register(@Body() dto: DevRegisterDto) {
    return this.devLogin.register(dto.email, dto.password, dto.display_name);
  }
}
