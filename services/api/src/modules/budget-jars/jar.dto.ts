import {
  ArrayMaxSize,
  IsArray,
  IsHexColor,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';

/**
 * Hũ ngân sách. `share_pct` là phần trăm của ngân sách tháng — số nguyên để
 * không lệch dấu phẩy động giữa máy và server.
 */
export class CreateJarDto {
  @IsUUID('4')
  id!: string;

  @IsString()
  @Length(1, 40)
  name!: string;

  @IsInt()
  @Min(1)
  @Max(100)
  share_pct!: number;

  @IsOptional()
  @IsHexColor()
  color?: string;

  @IsOptional()
  @IsInt()
  sort_order?: number;

  /**
   * Danh mục thuộc hũ này. Một danh mục nên thuộc một hũ: nếu gửi trùng giữa
   * hai hũ, service trả lỗi thay vì âm thầm ghi đè — người dùng cần biết vì
   * sao chi tiêu bị tính hai lần.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('4', { each: true })
  category_ids?: string[];
}

export class UpdateJarDto {
  /** Bắt buộc: chống ghi đè khi hai thiết bị sửa cùng lúc. */
  @IsInt()
  @Min(1)
  rev!: number;

  @IsOptional()
  @IsString()
  @Length(1, 40)
  name?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  share_pct?: number;

  @IsOptional()
  @IsHexColor()
  color?: string;

  @IsOptional()
  @IsInt()
  sort_order?: number;

  /** Gửi mảng (kể cả rỗng) để thay toàn bộ danh mục; bỏ qua để giữ nguyên. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('4', { each: true })
  category_ids?: string[];
}
