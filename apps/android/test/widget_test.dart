import 'package:android/ui/notifications/notifications_screen.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/wallets/wallets_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

Future<FakeBackend> _pump(
  WidgetTester tester, {
  FakeBackend? backend,
  Size size = const Size(360, 640),
}) async {
  final fake = backend ?? FakeBackend();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(testApp(fake));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('bottom navigation shows the required tabs',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.tabHome), findsWidgets);
    expect(find.text(AppStrings.tabTransactions), findsWidgets);
    expect(find.text(AppStrings.tabAdd), findsWidgets);
    expect(find.text(AppStrings.tabStats), findsWidgets);
    expect(find.text(AppStrings.tabAccount), findsWidgets);
  });

  testWidgets('home shows real data on a small 360x640 phone',
      (WidgetTester tester) async {
    await _pump(tester);
    expect(find.text(AppStrings.homeGreetingShort), findsOneWidget);
    // Tên lấy từ /v1/me, không phải chuỗi cứng trong app.
    expect(find.text('Tài khoản Test'), findsOneWidget);
    expect(find.text(AppStrings.balance), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Trang chủ dài hơn sau khi thêm hàng danh mục nhanh và thẻ thử thách,
    // nên cuộn tới đúng mục thay vì cuộn một khoảng cố định.
    await tester.scrollUntilVisible(
      find.text(AppStrings.recentTransactions),
      220,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.recentTransactions), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab renders without overflow on a small phone',
      (WidgetTester tester) async {
    await _pump(tester);
    for (final label in [
      AppStrings.tabTransactions,
      AppStrings.tabStats,
      AppStrings.tabAccount,
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow on $label');
    }
  });

  testWidgets('tài khoản chưa có dữ liệu thì hiện gợi ý thêm ví',
      (WidgetTester tester) async {
    // Không còn kịch bản giả để bấm: trạng thái trống do dữ liệu thật quyết
    // định, nên test phải giả lập đúng một tài khoản trống.
    await _pump(
      tester,
      backend: FakeBackend(
        income: 0,
        expense: 0,
        remaining: 0,
        dailyLimit: 0,
        hasBudget: false,
        wallets: [],
        transactions: [],
      ),
    );

    expect(find.text(AppStrings.noWalletTitle), findsOneWidget);
    expect(find.text(AppStrings.walletsOpen), findsOneWidget);
    // Tài khoản trống thì chỉ hiện lời mời thêm ví: không có ngân sách lẫn
    // giao dịch để nói tới, nên hai mục đó bị ẩn hẳn thay vì hiện khung rỗng.
    expect(find.text(AppStrings.budgetSection), findsNothing);
    expect(find.text(AppStrings.recentTransactions), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mất mạng thì hiện băng offline, không phải màn lỗi',
      (WidgetTester tester) async {
    final backend = FakeBackend()..offline = true;
    await _pump(tester, backend: backend);

    expect(find.text(AppStrings.offlineBanner), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });

  testWidgets('máy chủ lỗi thì hiện nút thử lại', (WidgetTester tester) async {
    final backend = FakeBackend()..failAll = true;
    await _pump(tester, backend: backend);

    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets('stats tab renders the category chart on a small phone',
      (WidgetTester tester) async {
    await _pump(tester);
    await tester.tap(find.text(AppStrings.tabStats).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.categories), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chuông hiện badge số tin chưa đọc và mở được hộp thư',
      (WidgetTester tester) async {
    final backend = await _pump(
      tester,
      backend: FakeBackend(
        notifications: [
          {
            'id': '5e000000-0000-4000-8000-000000000001',
            'type': 'budget_alert',
            'title': 'Ngân sách tháng 11 đã dùng 88%',
            'body': 'Còn 11 ngày, cân nhắc chi tiêu.',
            'read_at': null,
            'created_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
          },
        ],
      ),
    );

    // Badge đỏ là con số trong chuông, không phải chữ trên màn hình: kiểm
    // đúng widget badge thay vì đoán theo chuỗi "1".
    final badge = find.byKey(const ValueKey('unread-badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(AppStrings.notifications));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Ngân sách tháng 11 đã dùng 88%'), findsOneWidget);
    // Mở hộp thư là đánh dấu đã đọc — badge phải tắt sau khi quay lại.
    expect(
      backend.calls.where((c) => c.contains('read-all')),
      isNotEmpty,
    );
  });

  testWidgets('mở màn ví từ gợi ý trang chủ', (WidgetTester tester) async {
    await _pump(
      tester,
      backend: FakeBackend(
        income: 0,
        expense: 0,
        remaining: 0,
        dailyLimit: 0,
        hasBudget: false,
        wallets: [],
        transactions: [],
      ),
    );

    await tester.tap(find.text(AppStrings.walletsOpen));
    await tester.pumpAndSettle();

    expect(find.byType(WalletsScreen), findsOneWidget);
    expect(find.text(AppStrings.walletEmptyTitle), findsOneWidget);
  });
}
