import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, Max, Min } from 'class-validator';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { ReportsService } from './reports.service.js';

export class MonthSummaryQuery {
  @Type(() => Number)
  @IsInt()
  @Min(2000)
  @Max(2100)
  year!: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  month!: number;
}

@Controller('v1/reports')
@UseGuards(AuthGuard)
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get('month-summary')
  monthSummary(@Req() req: AuthedRequest, @Query() query: MonthSummaryQuery) {
    return this.reports.monthSummary(req.user.id, query.year, query.month);
  }
}
