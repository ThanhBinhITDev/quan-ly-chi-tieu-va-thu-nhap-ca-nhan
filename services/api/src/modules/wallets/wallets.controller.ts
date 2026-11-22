import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, Min } from 'class-validator';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { CreateWalletDto, UpdateWalletDto } from './wallet.dto.js';
import { WalletsService } from './wallets.service.js';

export class ListWalletsQuery {
  /** Đồng bộ offline cần biết ví nào đã bị xoá. Mặc định bỏ qua bản đã xoá. */
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) =>
    value === 'true' ? true : value === 'false' ? false : undefined,
  )
  include_deleted?: boolean;
}

export class DeleteWalletQuery {
  /** rev hiện tại + 1; gửi kèm để phát hiện xung đột. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  rev?: number;
}

@Controller('v1/wallets')
@UseGuards(AuthGuard)
export class WalletsController {
  constructor(private readonly wallets: WalletsService) {}

  @Get()
  list(@Req() req: AuthedRequest, @Query() query: ListWalletsQuery) {
    return this.wallets.list(req.user.id, query.include_deleted === true);
  }

  /**
   * Tổng hợp số dư. Đặt trước `:id` để không bị route tham số nuốt mất.
   */
  @Get('summary')
  summary(@Req() req: AuthedRequest) {
    return this.wallets.balances(req.user.id);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateWalletDto) {
    return this.wallets.create(req.user.id, dto);
  }

  @Delete(':id')
  remove(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Query() query: DeleteWalletQuery,
  ) {
    return this.wallets.remove(req.user.id, id, query.rev);
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
