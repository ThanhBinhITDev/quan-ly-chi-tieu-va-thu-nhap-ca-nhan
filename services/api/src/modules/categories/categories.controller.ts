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
import { IsIn, IsOptional } from 'class-validator';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import {
  CATEGORY_TYPES,
  CreateCategoryDto,
  UpdateCategoryDto,
} from './category.dto.js';
import { CategoriesService } from './categories.service.js';

export class ListCategoriesQuery {
  @IsOptional()
  @IsIn(CATEGORY_TYPES)
  type?: (typeof CATEGORY_TYPES)[number];
}

@Controller('v1/categories')
@UseGuards(AuthGuard)
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Get()
  list(@Req() req: AuthedRequest, @Query() query: ListCategoriesQuery) {
    return this.categories.list(req.user.id, query.type);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateCategoryDto) {
    return this.categories.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateCategoryDto,
  ) {
    return this.categories.update(req.user.id, id, dto);
  }
}
