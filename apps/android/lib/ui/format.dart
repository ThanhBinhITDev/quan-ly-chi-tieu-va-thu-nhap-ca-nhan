String formatMoney(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$sign$buffer đ';
}

String formatPercent(double value) => '${value.toStringAsFixed(1)}%';

/// Số tiền rút gọn cho nhãn trục biểu đồ: `12 nghìn`, `1,5 triệu`.
///
/// Trục Y chỉ rộng ~44px nên `1.350.000 đ` sẽ bị cắt. Ngưỡng tính bằng nghìn
/// vì người dùng Việt đọc tiền theo nghìn/triệu, không theo K/M.
String formatMoneyShort(int amount) {
  final abs = amount.abs();
  final sign = amount < 0 ? '-' : '';
  if (abs < 1000) return '$sign$abs';
  if (abs < 1000000) {
    final value = abs / 1000;
    final text = value >= 100 || value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return '$sign$text nghìn';
  }
  final value = abs / 1000000;
  final text = value >= 100 || value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');
  return '$sign$text tr';
}

/// Nhãn ngày cho dòng thời gian ảnh: "Hôm nay", "Hôm qua", "21/11", hoặc
/// "21/11/2025" khi khác năm — sổ ảnh có thể kéo dài nhiều năm nên chỉ ghi
/// ngày/tháng sẽ nhập nhằng.
String formatDayLabel(DateTime when) {
  final local = when.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  final dm = '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}';
  return day.year == today.year ? dm : '$dm/${day.year}';
}
