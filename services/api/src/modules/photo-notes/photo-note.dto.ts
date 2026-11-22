import { Type } from 'class-transformer';
import {
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';

export const PHOTO_MIMES = ['image/jpeg', 'image/png', 'image/webp'] as const;

/**
 * Tạo một tấm ảnh kèm ghi chú cho một giao dịch.
 *
 * `transaction_id` bắt buộc: ảnh luôn thuộc một khoản chi hoặc khoản thu,
 * không tồn tại độc lập. Chiều ngược lại mới tuỳ chọn — giao dịch không bắt
 * buộc phải có ảnh.
 */
export class CreatePhotoNoteDto {
  @IsUUID('4')
  id!: string;

  @IsUUID('4')
  transaction_id!: string;

  @IsOptional()
  @IsString()
  @Length(1, 500)
  caption?: string;

  /** Thời điểm ảnh được ghi lại; mặc định là lúc server nhận. */
  @IsOptional()
  @IsISO8601()
  taken_at?: string;

  /** Ảnh dạng base64. Server kiểm chữ ký tệp để chắc đúng là ảnh. */
  @IsString()
  photo_base64!: string;

  @IsString()
  photo_mime!: (typeof PHOTO_MIMES)[number];
}

export class UpdatePhotoNoteDto {
  /** Bắt buộc: chống ghi đè khi hai thiết bị sửa cùng lúc. */
  @IsInt()
  @Min(1)
  rev!: number;

  /** Ghi chú. Gửi chuỗi rỗng để xoá ghi chú, không gửi để giữ nguyên. */
  @IsOptional()
  @IsString()
  @Length(0, 500)
  caption?: string;

  @IsOptional()
  @IsISO8601()
  taken_at?: string;

  /**
   * Ảnh mới. Ảnh không bắt buộc nên không có cờ xoá ảnh: muốn bỏ ảnh thì
   * xoá cả dòng `photo_notes`, vì dòng tồn tại chính là để giữ ảnh.
   */
  @IsOptional()
  @IsString()
  photo_base64?: string;

  @IsOptional()
  @IsString()
  photo_mime?: (typeof PHOTO_MIMES)[number];
}

export class ListPhotoNotesQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  /** Cursor: lấy các bản ghi có taken_at nhỏ hơn mốc này. */
  @IsOptional()
  @IsISO8601()
  before?: string;

  /** Lọc ảnh của một giao dịch cụ thể. */
  @IsOptional()
  @IsUUID('4')
  transaction_id?: string;
}
