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
  CreateBudgetDto,
  ListBudgetsQuery,
  UpdateBudgetDto,
} from './budget.dto.js';
import { BudgetsService } from './budgets.service.js';

@Controller('v1/budgets')
@UseGuards(AuthGuard)
export class BudgetsController {
  constructor(private readonly budgets: BudgetsService) {}

  @Get()
  list(@Req() req: AuthedRequest, @Query() query: ListBudgetsQuery) {
    return this.budgets.list(req.user.id, query);
  }

  // Khai báo trước ':id' để 'progress' không bị hiểu là tham số đường dẫn.
  @Get('progress')
  progress(@Req() req: AuthedRequest) {
    return this.budgets.progress(req.user.id);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateBudgetDto) {
    return this.budgets.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateBudgetDto,
  ) {
    return this.budgets.update(req.user.id, id, dto);
  }
}
