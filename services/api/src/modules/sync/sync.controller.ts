import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { PullQuery, PushDto } from './sync.dto.js';
import { SyncService } from './sync.service.js';

@Controller('v1/sync')
@UseGuards(AuthGuard)
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Post('push')
  push(@Req() req: AuthedRequest, @Body() dto: PushDto) {
    return this.sync.push(req.user.id, dto);
  }

  @Get('pull')
  pull(@Req() req: AuthedRequest, @Query() query: PullQuery) {
    return this.sync.pull(req.user.id, query);
  }
}
