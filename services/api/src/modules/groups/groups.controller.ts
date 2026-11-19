import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import {
  CreateGroupDto,
  CreateSharedExpenseDto,
  JoinGroupDto,
  SettleDto,
} from './group.dto.js';
import { GroupsService } from './groups.service.js';

@Controller('v1/groups')
@UseGuards(AuthGuard)
export class GroupsController {
  constructor(private readonly groups: GroupsService) {}

  @Get()
  list(@Req() req: AuthedRequest) {
    return this.groups.list(req.user.id);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateGroupDto) {
    return this.groups.create(req.user.id, dto);
  }

  @Post('join')
  join(@Req() req: AuthedRequest, @Body() dto: JoinGroupDto) {
    return this.groups.join(req.user.id, dto);
  }

  @Get(':id/balances')
  balances(@Req() req: AuthedRequest, @Param('id') id: string) {
    return this.groups.balances(req.user.id, id);
  }

  @Post(':id/expenses')
  addExpense(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: CreateSharedExpenseDto,
  ) {
    return this.groups.addExpense(req.user.id, id, dto);
  }

  @Post(':id/settle')
  settle(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: SettleDto,
  ) {
    return this.groups.settle(req.user.id, id, dto);
  }
}
