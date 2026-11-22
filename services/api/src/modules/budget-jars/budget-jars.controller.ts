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
import { IsInt, Min } from 'class-validator';
import { Type } from 'class-transformer';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { BudgetJarsService } from './budget-jars.service.js';
import { CreateJarDto, UpdateJarDto } from './jar.dto.js';

class DeleteJarQuery {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  rev!: number;
}

@Controller('v1/budget-jars')
@UseGuards(AuthGuard)
export class BudgetJarsController {
  constructor(private readonly jars: BudgetJarsService) {}

  @Get()
  list(@Req() req: AuthedRequest) {
    return this.jars.list(req.user.id);
  }

  // Khai báo trước ':id' để 'progress' không bị hiểu là tham số đường dẫn.
  @Get('progress')
  progress(@Req() req: AuthedRequest) {
    return this.jars.progress(req.user.id);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateJarDto) {
    return this.jars.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateJarDto,
  ) {
    return this.jars.update(req.user.id, id, dto);
  }

  @Delete(':id')
  async remove(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Query() query: DeleteJarQuery,
  ) {
    await this.jars.remove(req.user.id, id, query.rev);
    return { ok: true };
  }
}
