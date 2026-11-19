import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Min,
} from 'class-validator';

export const CATEGORY_TYPES = ['expense', 'income'] as const;

export class CreateCategoryDto {
  @IsUUID('4')
  id!: string;

  @IsString()
  @Length(1, 60)
  name!: string;

  @IsIn(CATEGORY_TYPES)
  type!: (typeof CATEGORY_TYPES)[number];

  @IsOptional()
  @IsString()
  @Length(1, 40)
  icon?: string;

  @IsOptional()
  @IsString()
  @Length(4, 32)
  color?: string;

  @IsOptional()
  @IsUUID('4')
  parent_id?: string;
}

export class UpdateCategoryDto {
  @IsOptional()
  @IsString()
  @Length(1, 60)
  name?: string;

  @IsOptional()
  @IsString()
  @Length(1, 40)
  icon?: string;

  @IsOptional()
  @IsString()
  @Length(4, 32)
  color?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sort_order?: number;

  @IsInt()
  @Min(1)
  rev!: number;
}
