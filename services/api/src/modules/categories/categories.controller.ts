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
import { IsBoolean, IsIn, IsInt, IsOptional, Min } from 'class-validator';

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

  /** Đồng bộ offline cần biết danh mục nào đã bị xoá. */
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) =>
    value === 'true' ? true : value === 'false' ? false : undefined,
  )
  include_deleted?: boolean;
}

export class DeleteCategoryQuery {
  /** rev hiện tại + 1; gửi kèm để phát hiện xung đột. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  rev?: number;
}

@Controller('v1/categories')
@UseGuards(AuthGuard)
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Get()
  list(@Req() req: AuthedRequest, @Query() query: ListCategoriesQuery) {
    return this.categories.list(
      req.user.id,
      query.type,
      query.include_deleted === true,
    );
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateCategoryDto) {
    return this.categories.create(req.user.id, dto);
  }

  @Delete(':id')
  remove(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Query() query: DeleteCategoryQuery,
  ) {
    return this.categories.remove(req.user.id, id, query.rev);
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
