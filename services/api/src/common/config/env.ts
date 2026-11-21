/**
 * Đọc môi trường chạy. Một chỗ duy nhất để các module khác không tự đoán.
 */
export function isProduction(): boolean {
  return process.env.NODE_ENV === 'production';
}

/**
 * Chi tiết lỗi (thông báo gốc của Postgres, stack) chỉ nên trả cho client khi
 * đang phát triển. Ở production, thông báo của Postgres lộ tên bảng, tên
 * constraint và cấu trúc CSDL.
 */
export function publicErrorDetail(
  error: unknown,
  fallback = 'Không áp dụng được thay đổi',
): string {
  if (isProduction()) return fallback;
  return error instanceof Error ? error.message : fallback;
}
