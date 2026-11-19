import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsISO8601,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

/** Bảng được phép đồng bộ qua /v1/sync (khớp 03-sync-strategy). */
export const SYNC_TABLES = [
  'wallets',
  'categories',
  'transactions',
  'budgets',
  'goals',
  'recurring_rules',
] as const;

export const SYNC_OPS = ['insert', 'update', 'delete'] as const;

export class SyncChangeDto {
  @IsIn(SYNC_TABLES)
  table!: (typeof SYNC_TABLES)[number];

  @IsIn(SYNC_OPS)
  op!: (typeof SYNC_OPS)[number];

  @IsUUID('4')
  id!: string;

  @IsInt()
  @Min(1)
  rev!: number;

  @IsObject()
  data!: Record<string, unknown>;
}

export class PushDto {
  @IsUUID('4')
  device_id!: string;

  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => SyncChangeDto)
  changes!: SyncChangeDto[];
}

export class PullQuery {
  @IsISO8601()
  since!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  @IsOptional()
  @IsString()
  device_id?: string;
}
