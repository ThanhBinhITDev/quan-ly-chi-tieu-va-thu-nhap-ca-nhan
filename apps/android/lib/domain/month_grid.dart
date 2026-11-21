/// Lưới ngày của một tháng, tuần bắt đầu từ thứ Hai.
///
/// Tách khỏi UI vì đây là chỗ dễ sai nhất của lịch: tháng 2 năm nhuận, tháng
/// bắt đầu đúng vào thứ Hai, và ô đệm của tháng trước. Sai một ô là cả tháng
/// lệch, mà nhìn ảnh chụp khó phát hiện.
class MonthGrid {
  const MonthGrid({
    required this.year,
    required this.month,
    required this.leadingBlanks,
    required this.dayCount,
  });

  /// Ngày đầu tháng rơi vào cột nào (0 = thứ Hai … 6 = chủ nhật).
  final int leadingBlanks;
  final int dayCount;
  final int year;
  final int month;

  factory MonthGrid.of(DateTime anchor) {
    final first = DateTime(anchor.year, anchor.month);
    // DateTime.weekday: 1 = thứ Hai … 7 = chủ nhật. Đổi về 0..6.
    final weekdayIndex = first.weekday - 1;
    // Ngày 0 của tháng sau = ngày cuối tháng này, tự lo năm nhuận.
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    return MonthGrid(
      year: anchor.year,
      month: anchor.month,
      leadingBlanks: weekdayIndex,
      dayCount: daysInMonth,
    );
  }

  /// Ô cuối cùng của lưới (tính cả ô trống), đã làm tròn lên đủ tuần.
  ///
  /// Luôn đủ tuần để chiều cao lịch không nhảy khi đổi tháng: tháng 4 tuần,
  /// tháng 5 sáu tuần thì cả khung dưới nhảy theo, người dùng mất chỗ đang đọc.
  int get trailingBlanks => (7 - (leadingBlanks + dayCount) % 7) % 7;

  int get totalCells => leadingBlanks + dayCount + trailingBlanks;

  /// Ngày trong tháng (1..dayCount) ứng với ô thứ [cell], `null` nếu là ô đệm.
  int? dayAt(int cell) {
    final day = cell - leadingBlanks + 1;
    if (day < 1 || day > dayCount) return null;
    return day;
  }

  DateTime dateAt(int day) => DateTime(year, month, day);

  /// Tháng trước/sau, dùng cho nút chuyển tháng.
  MonthGrid shift(int months) => MonthGrid.of(DateTime(year, month + months));

  /// `YYYY-MM-DD`, khoá để tra giao dịch theo ngày.
  static String keyOf(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}

/// Dữ liệu một ngày trên lịch: tổng chi và ảnh đại diện.
class DayCell {
  const DayCell({
    required this.day,
    required this.date,
    this.expense = 0,
    this.income = 0,
    this.transactionCount = 0,
    this.photoTransactionId,
    this.isToday = false,
  });

  final int day;
  final DateTime date;
  final int expense;
  final int income;
  final int transactionCount;

  /// Id giao dịch có ảnh, để ô lịch tải thumbnail. Chỉ một ảnh/ngày: ô lịch
  /// nhỏ, nhiều ảnh thì không nhìn ra ảnh nào.
  final String? photoTransactionId;

  final bool isToday;

  bool get hasPhoto => photoTransactionId != null;
  bool get isEmpty => transactionCount == 0;
}

/// Dựng lưới ngày kèm số liệu từ danh sách giao dịch đã có.
///
/// Nhận danh sách phẳng thay vì tự gọi API: tab Giao dịch đã tải sẵn dữ liệu,
/// lịch chỉ việc gom theo ngày. Không có request thứ hai.
List<DayCell?> buildMonthCells({
  required MonthGrid grid,
  required Iterable<({DateTime occurredAt, int amount, bool isExpense, String id, bool hasPhoto})> items,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final byDay = <String, List<({DateTime occurredAt, int amount, bool isExpense, String id, bool hasPhoto})>>{};
  for (final item in items) {
    final key = MonthGrid.keyOf(item.occurredAt);
    (byDay[key] ??= []).add(item);
  }

  final cells = List<DayCell?>.filled(grid.totalCells, null);
  for (var cell = 0; cell < grid.totalCells; cell++) {
    final day = grid.dayAt(cell);
    if (day == null) continue;
    final date = grid.dateAt(day);
    final rows = byDay[MonthGrid.keyOf(date)] ?? const [];
    var expense = 0;
    var income = 0;
    String? photoId;
    for (final row in rows) {
      if (row.isExpense) {
        expense += row.amount;
      } else {
        income += row.amount;
      }
      // Ưu tiên ảnh của khoản chi lớn nhất đã gặp: ảnh đó thường là thứ đáng
      // nhớ nhất trong ngày.
      if (row.hasPhoto) photoId ??= row.id;
    }
    cells[cell] = DayCell(
      day: day,
      date: date,
      expense: expense,
      income: income,
      transactionCount: rows.length,
      photoTransactionId: photoId,
      isToday: date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    );
  }
  return cells;
}
