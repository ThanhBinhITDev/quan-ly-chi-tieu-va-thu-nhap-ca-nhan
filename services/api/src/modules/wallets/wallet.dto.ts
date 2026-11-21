import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Min,
} from 'class-validator';

export const WALLET_TYPES = ['cash', 'ewallet', 'bank', 'credit'] as const;

export class CreateWalletDto {
  @IsUUID('4')
  id!: string;

  @IsString()
  @Length(1, 80)
  name!: string;

  @IsIn(WALLET_TYPES)
  type!: (typeof WALLET_TYPES)[number];

  @IsOptional()
  @IsInt()
  initial_balance?: number;

  @IsOptional()
  @IsString()
  @Length(4, 32)
  color?: string;

  @IsOptional()
  @IsString()
  @Length(1, 40)
  icon?: string;
}

export class UpdateWalletDto {
  @IsOptional()
  @IsString()
  @Length(1, 80)
  name?: string;

  /**
   * Sửa số dư ban đầu. Cho phép vì người dùng hay nhập sai lúc tạo ví, và
   * không có đường nào khác để sửa: số dư hiện tại là số dư ban đầu cộng
   * giao dịch, nên chỉnh giao dịch không thay được mốc xuất phát.
   */
  @IsOptional()
  @IsInt()
  initial_balance?: number;

  @IsOptional()
  @IsString()
  @Length(4, 32)
  color?: string;

  @IsOptional()
  @IsString()
  @Length(1, 40)
  icon?: string;

  @IsOptional()
  @IsBoolean()
  is_archived?: boolean;

  /** rev hiện tại + 1; sai thì trả SYNC_CONFLICT. */
  @IsInt()
  @Min(1)
  rev!: number;
}
