import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { RegisterDeviceDto } from './device.dto.js';
import { DevicesService } from './devices.service.js';

@Controller('v1/devices')
@UseGuards(AuthGuard)
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  @Get()
  list(@Req() req: AuthedRequest) {
    return this.devices.list(req.user.id);
  }

  @Post()
  register(@Req() req: AuthedRequest, @Body() dto: RegisterDeviceDto) {
    return this.devices.register(req.user.id, dto);
  }
}
