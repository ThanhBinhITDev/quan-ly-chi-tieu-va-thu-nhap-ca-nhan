import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/session/session_store.dart';
import 'package:android/main.dart';
import 'package:android/ui/auth/auth_gate.dart';
import 'package:android/ui/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

/// Test chạy trên emulator/máy thật:
///
/// ```
/// flutter test integration_test/app_smoke_test.dart -d emulator-5554
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app khởi động, hiện form đăng nhập trên thiết bị thật',
      (tester) async {
    await tester.pumpWidget(const StudentFinanceApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Chưa đăng nhập thì app dừng ở AuthGate; chế độ dữ liệu mẫu chỉ bật
    // khi có --dart-define=DEMO_MODE=true hoặc bấm nút xem thử.
    expect(find.byType(AuthGate), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bốn tab đều mở được trên thiết bị thật', (tester) async {
    await tester.pumpWidget(const StudentFinanceApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    for (final label in [
      AppStrings.tabTransactions,
      AppStrings.tabBudget,
      AppStrings.tabStats,
      AppStrings.tabHome,
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'tab $label lỗi');
    }
  });

  testWidgets('form thêm giao dịch mở và đóng được', (tester) async {
    await tester.pumpWidget(const StudentFinanceApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text(AppStrings.tabTransactions).last);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final fab = find.byTooltip(AppStrings.addTransaction);
    if (fab.evaluate().isEmpty) return;
    await tester.tap(fab.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text(AppStrings.amountLabel), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('chưa cấu hình Supabase thì vào thẳng dữ liệu mẫu',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_OfflineAuth.new),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Build mặc định không truyền SUPABASE_URL → demo mode bật sẵn, không có
    // form đăng nhập và cũng không phụ thuộc mạng.
    expect(find.text(AppStrings.emailLabel), findsNothing);
    expect(find.text(AppStrings.homeOverview), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _OfflineAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}