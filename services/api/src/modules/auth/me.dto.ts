import { IsOptional, IsString, Length, Matches } from 'class-validator';

export const USER_PLANS = ['free', 'pro_month', 'pro_year', 'pro_student'] as const;

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @Length(1, 60)
  display_name?: string;

  /// Tên người dùng công khai. Chỉ chữ thường, số, dấu chấm và gạch dưới —
  /// khớp CHECK constraint `users_username_format` trong CSDL.
  @IsOptional()
  @IsString()
  @Length(3, 30)
  @Matches(/^[a-z0-9._]+$/, {
    message: 'Tên người dùng chỉ gồm chữ thường, số, dấu chấm và gạch dưới',
  })
  username?: string;

  @IsOptional()
  @IsString()
  @Length(3, 10)
  currency?: string;

  @IsOptional()
  @IsString()
  @Length(1, 60)
  timezone?: string;

  // `plan` cố ý KHÔNG nằm ở đây. Gói trả phí chỉ đổi được qua luồng thanh
  // toán (server đối soát với cổng thanh toán), không qua PATCH hồ sơ.
  // Trước đây DTO cho phép gửi `plan: 'pro_year'` nên người dùng tự nâng
  // cấp miễn phí chỉ bằng một request.
}

export class UpdateAvatarDto {
  /// `image/jpeg`, `image/png` hoặc `image/webp`. Server vẫn kiểm magic bytes.
  @IsString()
  @Matches(/^image\/(jpeg|png|webp)$/, {
    message: 'Định dạng ảnh không được hỗ trợ',
  })
  mime!: string;

  /// Ảnh đã cắt sẵn, mã hoá base64. Giới hạn thật kiểm ở service (256 KB).
  @IsString()
  @Length(64, 400_000)
  data!: string;
}
