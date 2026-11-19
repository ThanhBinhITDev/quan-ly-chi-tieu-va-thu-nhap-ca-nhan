import 'package:android/data/finance_repository.dart';
import 'package:android/domain/models.dart';
import 'package:android/main.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/scenario_menu.dart';
import 'package:android/ui/strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DemoModeOn extends DemoModeNotifier {
  @override
  bool build() => true;
}

/// Trả về dữ liệu thống kê cố định để kiểm đúng phần giao diện.
class _StubStats extends FakeFinanceRepository {
  _StubStats(this._stats);

  final StatsData _stats;

  @override
  Future<StatsData> getStats({
    required String range,
    required DemoScenario scenario,
  }) async =>
      _stats;
}

Future<void> _pump(WidgetTester tester, FinanceRepository repo) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoModeProvider.overrideWith(_DemoModeOn.new),
        financeRepositoryProvider.overrideWithValue(repo),
      ],
      child: const StudentFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openStats(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.tabStats).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kỳ trống vẫn còn bộ chọn kỳ để quay lại tháng này',
      (WidgetTester tester) async {
    await _pump(tester, FakeFinanceRepository(instant: true));
    await tester.tap(find.byType(ScenarioMenu).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.scenarioEmpty).last);
    await tester.pumpAndSettle();
    await _openStats(tester);

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
    await _pump(
      tester,
      _StubStats(
        const StatsData(
          categories: [
            CategoryTotal(name: 'Chưa phân loại', amount: 170000, percent: 100),
          ],
          daily: [],
          totalExpense: 170000,
          // null = tháng trước chưa chi gì, khác hẳn 0% (không đổi).
          comparisonPercent: null,
        ),
      ),
    );
    await _openStats(tester);

    expect(find.text(AppStrings.compareNoBaseline), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('có mốc so sánh thì hiện đúng %', (WidgetTester tester) async {
    await _pump(
      tester,
      _StubStats(
        const StatsData(
          categories: [
            CategoryTotal(name: 'Chưa phân loại', amount: 170000, percent: 100),
          ],
          daily: [],
          totalExpense: 170000,
          comparisonPercent: 70,
          previousExpense: 100000,
        ),
      ),
    );
    await _openStats(tester);

    expect(find.text('+70%'), findsOneWidget);
    expect(find.text(AppStrings.compareNoBaseline), findsNothing);
  });
}
