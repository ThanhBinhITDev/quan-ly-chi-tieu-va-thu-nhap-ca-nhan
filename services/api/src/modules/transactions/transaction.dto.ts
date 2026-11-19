import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';

export const TRANSACTION_TYPES = ['expense', 'income', 'transfer'] as const;
export const TRANSACTION_SOURCES = ['manual', 'ocr', 'recurring', 'quick'] as const;

export class CreateTransactionDto {
  @IsUUID('4')
  id!: string;

  @IsUUID('4')
  wallet_id!: string;

  @IsOptional()
  @IsUUID('4')
  category_id?: string;

  @IsIn(TRANSACTION_TYPES)
  type!: (typeof TRANSACTION_TYPES)[number];

  @IsInt()
  @Min(1)
  amount!: number;

  /** Bắt buộc khi type = transfer; phải khác wallet_id. */
  @ValidateIf((o: CreateTransactionDto) => o.type === 'transfer')
  @IsUUID('4')
  to_wallet_id?: string;

  @IsOptional()
  @IsString()
  @Length(0, 500)
  note?: string;

  @IsISO8601()
  occurred_at!: string;

  @IsOptional()
  @IsIn(TRANSACTION_SOURCES)
  source?: (typeof TRANSACTION_SOURCES)[number];
}

export class UpdateTransactionDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  amount?: number;

  @IsOptional()
  @IsUUID('4')
  category_id?: string;

  @IsOptional()
  @IsString()
  @Length(0, 500)
  note?: string;

  @IsOptional()
  @IsISO8601()
  occurred_at?: string;

  /** Xóa mềm: gửi thời điểm xóa thay vì gọi DELETE. */
  @IsOptional()
  @IsISO8601()
  deleted_at?: string;

  @IsInt()
  @Min(1)
  rev!: number;
}

export class ListTransactionsQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  /** Cursor: lấy các bản ghi có occurred_at nhỏ hơn mốc này. */
  @IsOptional()
  @IsISO8601()
  before?: string;

  @IsOptional()
  @IsIn(TRANSACTION_TYPES)
  type?: (typeof TRANSACTION_TYPES)[number];

  @IsOptional()
  @Transform(({ value }) => (value === 'true' ? true : value === 'false' ? false : undefined))
  include_deleted?: boolean;
}
