import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { CreateWalletDto, UpdateWalletDto } from './wallet.dto.js';
import { WalletsService } from './wallets.service.js';

@Controller('v1/wallets')
@UseGuards(AuthGuard)
export class WalletsController {
  constructor(private readonly wallets: WalletsService) {}

  @Get()
  list(@Req() req: AuthedRequest) {
    return this.wallets.list(req.user.id);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateWalletDto) {
    return this.wallets.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateWalletDto,
  ) {
    return this.wallets.update(req.user.id, id, dto);
  }
}
