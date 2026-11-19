import 'package:android/ui/strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

Future<void> _pump(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(testApp(backend));
  await tester.pumpAndSettle();
}

Future<void> _openStats(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.tabStats).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kỳ trống vẫn còn bộ chọn kỳ để quay lại tháng này',
      (WidgetTester tester) async {
    // Không còn công tắc kịch bản: kỳ trống là tài khoản thật sự chưa chi gì.
    await _pump(
      tester,
      FakeBackend(income: 0, expense: 0, remaining: 0, dailyLimit: 0),
    );
    await _openStats(tester);

    expect(find.text(AppStrings.emptyStats), findsOneWidget);
    await tester.tap(find.text(AppStrings.rangePrevious));
    await tester.pumpAndSettle();

    // Nếu ẩn cả bộ chọn kỳ khi trống, người dùng bị kẹt ở tháng trước.
    expect(find.text(AppStrings.rangeCurrent), findsOneWidget);
    expect(find.text(AppStrings.emptyStatsPrevious), findsOneWidget);

    await tester.tap(find.text(AppStrings.backToCurrentMonth));
    await tester.pumpAndSettle();

    // Quay lại được tháng hiện tại: thông báo đổi về câu chung.
    expect(find.text(AppStrings.emptyStatsPrevious), findsNothing);
  });

  testWidgets('không có mốc so sánh thì không hiện 0%',
      (WidgetTester tester) async {
    // previousExpense 0 + deltaPct null = tháng trước chưa chi gì, khác hẳn
    // 0% (chi tiêu không đổi).
    await _pump(
      tester,
      FakeBackend(expense: 170000, previousExpense: 0, deltaPct: null),
    );
    await _openStats(tester);

    expect(find.text(AppStrings.compareNoBaseline), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('có mốc so sánh thì hiện đúng %', (WidgetTester tester) async {
    await _pump(
      tester,
      FakeBackend(expense: 170000, previousExpense: 100000, deltaPct: 70),
    );
    await _openStats(tester);

    expect(find.text('+70%'), findsOneWidget);
    expect(find.text(AppStrings.compareNoBaseline), findsNothing);
  });

  testWidgets('chọn "Tháng trước" thì gọi API với tháng trước thật',
      (WidgetTester tester) async {
    // Trước đây chip chỉ đổi nhãn: dữ liệu vẫn là tháng này. Kiểm query gửi
    // lên để lỗi đó không quay lại.
    final backend = FakeBackend(expense: 170000, previousExpense: 100000);
    await _pump(tester, backend);
    await _openStats(tester);

    await tester.tap(find.text(AppStrings.rangePrevious));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    final queries = backend.monthSummaryQueries;
    expect(queries, isNotEmpty);
    expect(queries.last['year'], previous.year);
    expect(queries.last['month'], previous.month);
  });
}
