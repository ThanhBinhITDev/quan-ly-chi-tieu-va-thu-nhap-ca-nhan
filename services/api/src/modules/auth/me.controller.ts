import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Put,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { UpdateAvatarDto, UpdateMeDto } from './me.dto.js';
import { MeService } from './me.service.js';

/** Hồ sơ người dùng hiện tại. */
@Controller('v1/me')
@UseGuards(AuthGuard)
export class MeController {
  constructor(private readonly me: MeService) {}

  @Get()
  get(@Req() req: AuthedRequest) {
    return this.me.ensure(req.user);
  }

  @Patch()
  update(@Req() req: AuthedRequest, @Body() dto: UpdateMeDto) {
    return this.me.update(req.user.id, dto);
  }

  /**
   * Ảnh đại diện. Trả `{ mime, data }` trong JSON thay vì multipart: app đã
   * cắt ảnh về 256×256 (~40 KB) nên base64 chỉ ~54 KB, đơn giản hơn nhiều so
   * với thêm một thư viện multipart ở cả hai đầu.
   */
  @Put('avatar')
  putAvatar(@Req() req: AuthedRequest, @Body() dto: UpdateAvatarDto) {
    return this.me.putAvatar(req.user.id, dto.mime, dto.data);
  }

  /**
   * Ảnh lấy riêng, không nhét vào hồ sơ: dashboard không phải tải ảnh mỗi lần.
   *
   * `Cache-Control: private, no-cache` + `ETag` theo `avatar_updated_at`: trình
   * duyệt giữ ảnh cũ trong bộ nhớ đệm và chỉ tải lại khi ảnh thật sự đổi.
   * `private` là bắt buộc — proxy dùng chung không được giữ ảnh của một người.
   */
  @Get('avatar')
  async getAvatar(
    @Req() req: AuthedRequest,
    @Res() res: Response,
  ): Promise<void> {
    const avatar = await this.me.getAvatar(req.user.id);
    if (!avatar) {
      res.status(404).json({
        error: { code: 'NOT_FOUND', message: 'Chưa có ảnh đại diện' },
      });
      return;
    }
    // Ghi thẳng bytes: nếu trả Buffer qua `return`, Nest serializes thành
    // JSON `{"type":"Buffer","data":[...]}` và ảnh hỏng.
    res.setHeader('ETag', `"${avatar.etag}"`);
    res.setHeader('Content-Type', avatar.mime);
    res.setHeader('Cache-Control', 'private, no-cache');
    res.setHeader('Content-Disposition', 'inline');
    res.setHeader('Content-Length', String(avatar.data.length));
    res.status(200).end(avatar.data);
  }

  @Delete('avatar')
  removeAvatar(@Req() req: AuthedRequest) {
    return this.me.removeAvatar(req.user.id);
  }
}
