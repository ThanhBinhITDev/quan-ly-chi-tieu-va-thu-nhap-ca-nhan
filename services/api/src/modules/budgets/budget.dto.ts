import { Transform } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsUUID,
  Min,
  ValidateIf,
} from 'class-validator';

export const BUDGET_PERIODS = ['week', 'month'] as const;

export class CreateBudgetDto {
  @IsUUID('4')
  id!: string;

  /** null = ngân sách tổng. */
  @IsOptional()
  @ValidateIf((o: CreateBudgetDto) => o.category_id !== null)
  @IsUUID('4')
  category_id?: string | null;

  @IsInt()
  @Min(1)
  amount!: number;

  @IsIn(BUDGET_PERIODS)
  period!: (typeof BUDGET_PERIODS)[number];

  @IsISO8601()
  start_date!: string;
}

export class UpdateBudgetDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  amount?: number;

  @IsOptional()
  @IsISO8601()
  end_date?: string;

  @IsOptional()
  @IsISO8601()
  deleted_at?: string;

  @IsInt()
  @Min(1)
  rev!: number;
}

export class ListBudgetsQuery {
  @IsOptional()
  @Transform(({ value }) =>
    value === 'true' ? true : value === 'false' ? false : undefined,
  )
  active?: boolean;
}
