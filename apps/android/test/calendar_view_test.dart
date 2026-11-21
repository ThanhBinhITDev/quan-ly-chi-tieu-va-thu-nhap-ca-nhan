import 'package:android/ui/strings.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

/// Hai khoản chi trong tháng hiện tại, một có ảnh một không, cộng một khoản
/// của tháng trước để chắc lịch không cộng lẫn.
List<Map<String, dynamic>> _seed() {
  final now = DateTime.now();
  String iso(int year, int month, int day) => DateTime(year, month, day, 10)
      .toUtc()
      .toIso8601String();
  return [
    {
      'id': 'tx-photo',
      'amount': 45000,
      'type': 'expense',
      'category_id': 'cat-food',
      'wallet_id': 'wallet-cash',
      'note': 'Bún bò',
      'rev': 1,
      'occurred_at': iso(now.year, now.month, 4),
      'occurred_on': '${now.year}-${now.month.toString().padLeft(2, '0')}-04',
      'has_receipt': true,
      'receipt_mime': 'image/jpeg',
      'created_at': iso(now.year, now.month, 4),
      'updated_at': iso(now.year, now.month, 4),
      'deleted_at': null,
    },
    {
      'id': 'tx-plain',
      'amount': 15000,
      'type': 'expense',
      'category_id': 'cat-food',
      'wallet_id': 'wallet-cash',
      'note': 'Trà đá',
      'rev': 1,
      'occurred_at': iso(now.year, now.month, 4),
      'occurred_on': '${now.year}-${now.month.toString().padLeft(2, '0')}-04',
      'has_receipt': false,
      'created_at': iso(now.year, now.month, 4),
      'updated_at': iso(now.year, now.month, 4),
      'deleted_at': null,
    },
    {
      'id': 'tx-old',
      'amount': 99000,
      'type': 'expense',
      'category_id': 'cat-food',
      'wallet_id': 'wallet-cash',
      'note': 'Tháng trước',
      'rev': 1,
      'occurred_at': iso(now.year, now.month - 1, 20),
      'occurred_on': '${now.year}-${now.month.toString().padLeft(2, '0')}-20',
      'has_receipt': false,
      'created_at': iso(now.year, now.month - 1, 20),
      'updated_at': iso(now.year, now.month - 1, 20),
      'deleted_at': null,
    },
  ];
}

Future<FakeBackend> _openCalendar(WidgetTester tester) async {
  final fake = FakeBackend(transactions: _seed());
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(testApp(fake));
  await tester.pumpAndSettle();

  await tester.tap(find.text(AppStrings.tabTransactions).last);
  await tester.pumpAndSettle();
  // Nút chuyển nằm trong AppBar của tab Giao dịch.
  await tester.tap(find.text(AppStrings.viewCalendar));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('chuyển từ danh sách sang lịch mà không tràn khung',
      (WidgetTester tester) async {
    await _openCalendar(tester);
    expect(find.text(AppStrings.calendarTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lịch cộng đúng tiền của ngày và bỏ khoản tháng trước',
      (WidgetTester tester) async {
    await _openCalendar(tester);
    final now = DateTime.now();
    // 45.000 + 15.000 của ngày 4; khoản 99.000 thuộc tháng trước nên không
    // được xuất hiện trong tổng tháng này.
    expect(
      find.textContaining('Tháng ${now.month}, ${now.year}'),
      findsOneWidget,
    );
    expect(find.textContaining('60.000'), findsWidgets);
    expect(find.textContaining('99.000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bấm một ngày mở danh sách khoản của ngày đó',
      (WidgetTester tester) async {
    await _openCalendar(tester);
    // Ngày 4 có hai khoản. Chạm vào ô lịch của ngày 4 (ô không có ảnh sẽ
    // hiện số "4"; ô có ảnh cũng có số nhưng chồng lên ảnh).
    final cells = find.byType(InkWell);
    expect(cells, findsWidgets);
    // Ghi chú "Bún bò" không phải một Text riêng: TransactionTile ghép nó vào
    // chuỗi "Hôm nay · Ví · Bún bò", nên phải tìm theo phần chứa.
    expect(find.textContaining('Bún bò'), findsNothing);
    await tester.tap(find.text('4').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bún bò'), findsWidgets);
    expect(find.textContaining('Trà đá'), findsWidgets);
    expect(find.text(AppStrings.calendarDayTotal), findsOneWidget);
  });

  testWidgets('lùi tháng thì thấy khoản của tháng trước',
      (WidgetTester tester) async {
    await _openCalendar(tester);
    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pumpAndSettle();
    expect(find.textContaining('99.000'), findsWidgets);
    // Có nút về tháng hiện tại khi đang xem tháng cũ.
    expect(find.text(AppStrings.calendarToday), findsOneWidget);
  });

  testWidgets('tháng không có khoản nào thì hiện lời nhắc trống',
      (WidgetTester tester) async {
    final fake = FakeBackend(transactions: const []);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(fake));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.tabTransactions).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.viewCalendar));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calendarEmptyMonth), findsOneWidget);
  });

  testWidgets('lịch và danh sách dùng chung dữ liệu, không gọi lại API',
      (WidgetTester tester) async {
    final fake = await _openCalendar(tester);
    int listCalls() =>
        fake.calls.where((call) => call == 'GET /v1/transactions').length;
    final before = listCalls();
    await tester.tap(find.text(AppStrings.viewList));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.viewCalendar));
    await tester.pumpAndSettle();
    expect(listCalls(), before,
        reason: 'đổi chế độ xem không được tải lại danh sách');
  });

  testWidgets('ảnh hỏng hiện icon, không vẽ chuỗi ngoại lệ ra ô lịch',
      (WidgetTester tester) async {
    // Đây là lỗi gặp thật trên emulator: ảnh 1x1 hỏng làm Flutter vẽ nguyên
    // "Exception: Could not decompress image." vào ô lịch. Chặn lại bằng test.
    final fake = FakeBackend(
      transactions: [
        {
          'id': 'tx-broken',
          'amount': 20000,
          'type': 'expense',
          'category_id': 'cat-food',
          'wallet_id': 'wallet-cash',
          'note': 'Ảnh hỏng',
          'rev': 1,
          'occurred_at': DateTime.now().toUtc().toIso8601String(),
          'has_receipt': true,
          'receipt_mime': 'image/png',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'deleted_at': null,
        },
      ],
    );
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(fake));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.tabTransactions).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.viewCalendar));
    await tester.pumpAndSettle();

    expect(find.textContaining('Exception'), findsNothing);
    // Không tải được ảnh (ở đây là giao dịch không kèm bytes) thì ô lịch hiện
    // icon "ảnh hỏng", không phải chữ.
    expect(find.byIcon(LucideIcons.imageOff), findsWidgets);
  });
}
