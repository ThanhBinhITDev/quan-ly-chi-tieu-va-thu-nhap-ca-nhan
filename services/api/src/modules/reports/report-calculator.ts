/**
 * Công thức dùng chung (hợp đồng API, mục 9). Phải khớp với bản Dart
 * trong apps/android/lib/domain/finance_calculator.dart.
 *
 * Quy tắc bắt buộc:
 * 1. daily_limit làm tròn XUỐNG.
 * 2. days_left tính cả hôm nay.
 * 3. remaining <= 0 thì daily_limit = remaining (số âm), không chia.
 * 4. spent chỉ cộng type = 'expense'; transfer không tính.
 */
export function daysLeftInPeriod(today: Date, start: Date, end: Date): number {
  const day = startOfDayUtc(today);
  const endDay = startOfDayUtc(end);
  if (day > endDay) return 0;
  const startDay = startOfDayUtc(start);
  const from = day < startDay ? startDay : day;
  const diff = Math.round((endDay.getTime() - from.getTime()) / 86_400_000);
  return diff + 1; // tính cả hôm nay
}

export function dailyLimit(remaining: number, daysLeft: number): number {
  if (remaining <= 0) return remaining;
  if (daysLeft <= 0) return remaining;
  return Math.floor(remaining / daysLeft);
}

export function startOfDayUtc(value: Date): Date {
  return new Date(
    Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
  );
}

/** Kỳ tháng theo giờ Việt Nam (UTC+7), trả về mốc ngày dạng YYYY-MM-DD. */
export function vietnamMonthRange(year: number, month: number): {
  start: string;
  end: string;
} {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const pad = (n: number) => String(n).padStart(2, '0');
  return {
    start: `${year}-${pad(month)}-01`,
    end: `${year}-${pad(month)}-${pad(lastDay)}`,
  };
}

export function percent(part: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((part / total) * 1000) / 10;
}
