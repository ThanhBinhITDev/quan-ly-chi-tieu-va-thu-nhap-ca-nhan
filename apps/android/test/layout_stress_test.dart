import 'package:android/ui/common/cards.dart';
import 'package:android/ui/strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

/// Quét bố cục ở điều kiện khắc nghiệt: màn hẹp 320×568 (nhỏ hơn cả máy
/// 360×640 thường dùng) và chữ phóng 200%.
///
/// Người dùng thật hay bật cỡ chữ lớn vì mắt kém, và đó là lúc lưới ảnh,
/// hàng tiền tệ hay nhãn nút dễ tràn ra ngoài khung. Test này bắt đúng loại
/// lỗi "không thể tải dữ liệu" kèm dải vàng đen mà chỉ hiện trên máy thật.

/// Cuộn trang chủ tới thẻ ngân sách rồi mở màn Chia hủ.
Future<void> _openJarsFromHome(WidgetTester tester) async {
  final entry = find.widgetWithText(TextButton, AppStrings.jarTitle);
  await tester.scrollUntilVisible(entry, 200, maxScrolls: 40);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  Future<FakeBackend> pumpTight(WidgetTester tester, [FakeBackend? backend]) async {
    final fake = backend ?? FakeBackend();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp(fake));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('trang chủ không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    await pumpTight(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab giao dịch không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    await pumpTight(tester);
    await tester.tap(find.text(AppStrings.tabTransactions).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lịch không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    await pumpTight(tester);
    await tester.tap(find.text(AppStrings.tabTransactions).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.viewCalendar));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sổ ảnh không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    final fake = FakeBackend(
      photoNotes: [
        {
          'id': 'p1',
          'transaction_id': 'tx-1',
          'caption': 'Bún bò sáng nay ăn cùng anh Hùng và chị Lan ở quán quen '
              'đầu ngõ, trời mưa nên đông khách phải chờ khá lâu',
          'photo_mime': 'image/png',
          'photo_base64': '',
          'has_photo': true,
          'taken_at': DateTime.now().toUtc().toIso8601String(),
          'taken_on': '2026-11-04',
          'rev': 1,
          'deleted_at': null,
        },
      ],
    );
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp(fake));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.tabTransactions).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.viewPhotos));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn chia hủ không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    // Tên hũ dài + tỷ lệ + số tiền trên 320dp với chữ 200% là tổ hợp dễ tràn
    // nhất: hàng tên hũ có ba phần tử, hàng tiền có hai cột.
    final fake = FakeBackend(
      budgetTotal: 3000000,
      expenseByCategory: {'5b000000-0000-4000-8000-000000000001': 900000},
      budgetJars: [
        {
          'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'name': 'Ăn uống ngoài và cà phê với bạn bè',
          'share_pct': 45,
          'category_ids': ['5b000000-0000-4000-8000-000000000001'],
          'color': null,
          'rev': 1,
        },
        {
          'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          'name': 'Để dành',
          'share_pct': 30,
          'category_ids': <String>[],
          'color': '#2D7C3D',
          'rev': 1,
        },
      ],
    );
    await pumpTight(tester, fake);
    // Mở từ trang chủ: ở 320dp chữ 200% tab Ngân sách bị danh sách mục che
    // mất, còn lối vào này luôn bấm được. Phải cuộn vì ListView dựng lười —
    // mục ngân sách nằm dưới màn hình đầu.
    await _openJarsFromHome(tester);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.jarTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet tạo hũ không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    final fake = FakeBackend(
      budgetJars: [
        {
          'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'name': 'Ăn uống',
          'share_pct': 40,
          'category_ids': <String>[],
          'color': null,
          'rev': 1,
        },
      ],
    );
    await pumpTight(tester, fake);
    await _openJarsFromHome(tester);
    await tester.tap(find.byTooltip(AppStrings.jarAdd));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.jarNewTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thống kê không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    await pumpTight(tester);
    await tester.tap(find.text(AppStrings.tabStats).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('form ghi giao dịch không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    await pumpTight(tester);
    await tester.tap(find.text(AppStrings.tabAdd).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('chi tiết giao dịch không tràn ở màn hẹp, chữ 200%',
      (WidgetTester tester) async {
    await pumpTight(
      tester,
      FakeBackend(transactions: [
        {
          'id': 'tx-1',
          'amount': 45000,
          'type': 'expense',
          'category_id': 'cat-1',
          'wallet_id': 'w-1',
          'note': 'Bún bò sáng nay ăn cùng anh Hùng và chị Lan ở quán quen đầu ngõ',
          'rev': 1,
          'occurred_at': DateTime.now().toUtc().toIso8601String(),
          'occurred_on': '2026-11-04',
          'has_receipt': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'deleted_at': null,
        },
      ]),
    );
    await tester.tap(find.text(AppStrings.tabTransactions).last);
    await tester.pumpAndSettle();
    // Chạm khoản chi đầu tiên để mở hộp chi tiết.
    await tester.tap(find.byType(TransactionTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
