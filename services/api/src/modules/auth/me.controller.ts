import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { UpdateMeDto } from './me.dto.js';
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
}
