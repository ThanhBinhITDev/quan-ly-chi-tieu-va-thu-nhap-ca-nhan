import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { Transform, Type } from 'class-transformer';

/**
 * Tham số lọc hộp thư thông báo.
 *
 * Có `unread_only` vì chuông cần biết số chưa đọc mà không phải tải cả hộp
 * thư; giới hạn `limit` để một người dùng lâu năm không kéo về hàng nghìn
 * dòng trong một request.
 */
export class ListNotificationsQuery {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Type(() => Number)
  limit?: number;

  @IsOptional()
  @Transform(({ value }) =>
    value === 'true' ? true : value === 'false' ? false : undefined,
  )
  unread_only?: boolean;
}
