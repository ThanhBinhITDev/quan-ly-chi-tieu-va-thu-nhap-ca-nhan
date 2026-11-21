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
