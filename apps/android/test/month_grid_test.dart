import 'package:flutter_test/flutter_test.dart';

import 'package:android/domain/month_grid.dart';

void main() {
  group('MonthGrid', () {
    test('tháng 11/2026 bắt đầu vào chủ nhật nên đệm sáu ô', () {
      // 1/11/2026 là chủ nhật — DateTime.weekday = 7, cột 6. Đây là ca mà
      // lịch viết tay hay sai nhất vì đệm gần hết tuần đầu.
      final grid = MonthGrid.of(DateTime(2026, 11, 1));
      expect(grid.leadingBlanks, 6);
      expect(grid.dayCount, 30);
      expect(grid.dayAt(6), 1);
      expect(grid.dayAt(5), isNull);
      expect(grid.dayAt(35), 30);
    });

    test('tháng bắt đầu đúng thứ Hai thì không đệm', () {
      // 1/6/2026 là thứ Hai.
      final grid = MonthGrid.of(DateTime(2026, 6, 15));
      expect(grid.leadingBlanks, 0);
      expect(grid.dayAt(0), 1);
      expect(grid.dayCount, 30);
    });

    test('tháng 2 năm nhuận có 29 ngày, năm thường 28', () {
      expect(MonthGrid.of(DateTime(2028, 2, 1)).dayCount, 29);
      expect(MonthGrid.of(DateTime(2026, 2, 1)).dayCount, 28);
      // 2000 là năm nhuận (chia hết 400), 1900 thì không — bẫy kinh điển.
      expect(MonthGrid.of(DateTime(2000, 2, 1)).dayCount, 29);
    });

    test('lưới luôn đủ tuần để chiều cao lịch không nhảy', () {
      for (var month = 1; month <= 12; month++) {
        for (var year = 2024; year <= 2028; year++) {
          final grid = MonthGrid.of(DateTime(year, month, 1));
          expect(grid.totalCells % 7, 0,
              reason: 'tháng $month/$year có ${grid.totalCells} ô');
        }
      }
    });

    test('đệm cuối bù cho đủ tuần, không thừa cả tuần', () {
      final grid = MonthGrid.of(DateTime(2026, 11, 1));
      // 6 đệm đầu + 30 ngày = 36 ô, cần thêm 6 để đủ 42.
      expect(grid.trailingBlanks, 6);
      expect(grid.totalCells, 42);
    });

    test('chuyển tháng qua lại không mất năm', () {
      final dec = MonthGrid.of(DateTime(2026, 12, 5));
      expect(dec.shift(1).month, 1);
      expect(dec.shift(1).year, 2027);
      expect(dec.shift(-1).month, 11);
      expect(dec.shift(-1).year, 2026);
      expect(dec.shift(13).month, 1);
      expect(dec.shift(13).year, 2028);
    });

    test('keyOf luôn hai chữ số để so khớp với occurred_on của server', () {
      expect(MonthGrid.keyOf(DateTime(2026, 1, 5)), '2026-01-05');
      expect(MonthGrid.keyOf(DateTime(2026, 11, 21)), '2026-11-21');
    });
  });

  group('buildMonthCells', () {
    test('gom tiền theo ngày, tách chi và thu', () {
      final grid = MonthGrid.of(DateTime(2026, 11, 1));
      final cells = buildMonthCells(
        grid: grid,
        now: DateTime(2026, 11, 21),
        items: [
          (occurredAt: DateTime(2026, 11, 3, 8), amount: 30000, isExpense: true, id: 'a', hasPhoto: false),
          (occurredAt: DateTime(2026, 11, 3, 19), amount: 20000, isExpense: true, id: 'b', hasPhoto: false),
          (occurredAt: DateTime(2026, 11, 3, 20), amount: 500000, isExpense: false, id: 'c', hasPhoto: false),
        ],
      );
      final day3 = cells.firstWhere((c) => c?.day == 3)!;
      expect(day3.expense, 50000);
      expect(day3.income, 500000);
      expect(day3.transactionCount, 3);
    });

    test('ngày có ảnh thì nhớ id ảnh đầu tiên', () {
      final grid = MonthGrid.of(DateTime(2026, 11, 1));
      final cells = buildMonthCells(
        grid: grid,
        now: DateTime(2026, 11, 21),
        items: [
          (occurredAt: DateTime(2026, 11, 7, 9), amount: 1000, isExpense: true, id: 'no-photo', hasPhoto: false),
          (occurredAt: DateTime(2026, 11, 7, 12), amount: 2000, isExpense: true, id: 'with-photo', hasPhoto: true),
        ],
      );
      final day7 = cells.firstWhere((c) => c?.day == 7)!;
      expect(day7.photoTransactionId, 'with-photo');
      expect(day7.hasPhoto, isTrue);
    });

    test('bỏ giao dịch của tháng khác ra khỏi lưới', () {
      final grid = MonthGrid.of(DateTime(2026, 11, 1));
      final cells = buildMonthCells(
        grid: grid,
        now: DateTime(2026, 11, 21),
        items: [
          (occurredAt: DateTime(2026, 10, 30, 9), amount: 999, isExpense: true, id: 'x', hasPhoto: false),
          (occurredAt: DateTime(2026, 12, 2, 9), amount: 999, isExpense: true, id: 'y', hasPhoto: false),
        ],
      );
      final filled = cells.whereType<DayCell>().toList();
      expect(filled.every((c) => c.isEmpty), isTrue);
      expect(filled.fold<int>(0, (sum, c) => sum + c.expense), 0);
    });

    test('đánh dấu hôm nay, và không đánh dấu khi sang tháng khác', () {
      final grid = MonthGrid.of(DateTime(2026, 11, 1));
      final cells = buildMonthCells(
        grid: grid,
        now: DateTime(2026, 11, 21),
        items: const [],
      );
      final today = cells.whereType<DayCell>().where((c) => c.isToday).toList();
      expect(today.length, 1);
      expect(today.single.day, 21);
    });

    test('ô đệm là null, không phải ngày 0 hay ngày 31', () {
      final grid = MonthGrid.of(DateTime(2026, 11, 1));
      final cells = buildMonthCells(grid: grid, now: DateTime(2026, 11, 21), items: const []);
      expect(cells.take(6).every((c) => c == null), isTrue);
      expect(cells.whereType<DayCell>().length, 30);
    });
  });
}
