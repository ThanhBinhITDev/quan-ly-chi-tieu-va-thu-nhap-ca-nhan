import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import {
  CreateTransactionDto,
  ListTransactionsQuery,
  UpdateTransactionDto,
} from './transaction.dto.js';
import { TransactionsService } from './transactions.service.js';

@Controller('v1/transactions')
@UseGuards(AuthGuard)
export class TransactionsController {
  constructor(private readonly transactions: TransactionsService) {}

  @Get()
  list(@Req() req: AuthedRequest, @Query() query: ListTransactionsQuery) {
    return this.transactions.list(req.user.id, query);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateTransactionDto) {
    return this.transactions.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateTransactionDto,
  ) {
    return this.transactions.update(req.user.id, id, dto);
  }
}
