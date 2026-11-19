import 'package:android/data/finance_repository.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 640),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Test này kiểm giao diện app, không kiểm luồng đăng nhập: bật chế độ
        // xem thử để vào thẳng AppShell với dữ liệu giả.
        demoModeProvider.overrideWith(_DemoModeOn.new),
        financeRepositoryProvider.overrideWithValue(
          FakeFinanceRepository(instant: true),
        ),
      ],
      child: const StudentFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectScenario(WidgetTester tester, String label) async {
  await tester.tap(find.byType(ScenarioMenu).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bottom navigation shows the four required tabs',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.tabHome), findsOneWidget);
    expect(find.text(AppStrings.tabTransactions), findsOneWidget);
    expect(find.text(AppStrings.tabBudget), findsOneWidget);
    expect(find.text(AppStrings.tabStats), findsOneWidget);
  });

  testWidgets('home shows real data on a small 360x640 phone',
      (WidgetTester tester) async {
    await _pump(tester);
    expect(find.text(AppStrings.homeOverview), findsOneWidget);
    expect(find.text(AppStrings.balance), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.recentTransactions), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab renders without overflow on a small phone',
      (WidgetTester tester) async {
    await _pump(tester);
    for (final label in [
      AppStrings.tabTransactions,
      AppStrings.tabBudget,
      AppStrings.tabStats,
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow on $label');
    }
  });

  testWidgets('empty scenario shows the empty home state',
      (WidgetTester tester) async {
    await _pump(tester);
    await _selectScenario(tester, AppStrings.scenarioEmpty);
    expect(find.text(AppStrings.emptyHome), findsOneWidget);
  });

  testWidgets('offline scenario shows the offline banner',
      (WidgetTester tester) async {
    await _pump(tester);
    await _selectScenario(tester, AppStrings.scenarioOffline);
    expect(find.text(AppStrings.offlineBanner), findsOneWidget);
  });

  testWidgets('error scenario shows a retry action',
      (WidgetTester tester) async {
    await _pump(tester);
    await _selectScenario(tester, AppStrings.scenarioError);
    expect(find.text(AppStrings.retry), findsWidgets);
  });

  testWidgets('stats tab renders the category chart on a small phone',
      (WidgetTester tester) async {
    await _pump(tester);
    await tester.tap(find.text(AppStrings.tabStats).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.categories), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
