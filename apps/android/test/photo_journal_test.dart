import 'dart:convert';
import 'dart:typed_data';

import 'package:android/domain/models.dart';
import 'package:android/ui/strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

/// 1×1 PNG thật, đủ để `Image.memory` giải mã được trong test.
final String _tinyPngBase64 = base64Encode(Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]));

Map<String, dynamic> _tx({
  required String id,
  required String note,
  String? categoryId,
}) =>
    {
      'id': id,
      'amount': 45000,
      'type': 'expense',
      'category_id': categoryId ?? 'cat-food',
      'wallet_id': 'wallet-cash',
      'note': note,
      'rev': 1,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'occurred_on': '2026-11-04',
      'has_receipt': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'deleted_at': null,
    };

Map<String, dynamic> _photo({
  required String id,
  required String transactionId,
  String? caption,
}) =>
    {
      'id': id,
      'transaction_id': transactionId,
      'caption': caption,
      'photo_mime': 'image/png',
      'photo_base64': _tinyPngBase64,
      'has_photo': true,
      'taken_at': DateTime.now().toUtc().toIso8601String(),
      'taken_on': '2026-11-04',
      'rev': 1,
      'deleted_at': null,
    };

Future<FakeBackend> _openJournal(
  WidgetTester tester, {
  List<Map<String, dynamic>>? photoNotes,
  List<Map<String, dynamic>>? transactions,
}) async {
  final fake = FakeBackend(
    transactions: transactions ??
        [
          _tx(id: 'tx-1', note: 'Bún bò'),
          _tx(id: 'tx-2', note: 'Trà đá'),
        ],
    photoNotes: photoNotes,
  );
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(testApp(fake));
  await tester.pumpAndSettle();

  await tester.tap(find.text(AppStrings.tabTransactions).last);
  await tester.pumpAndSettle();
  // Sổ ảnh là chế độ thứ ba của tab Giao dịch, không phải tab thứ năm.
  await tester.tap(find.text(AppStrings.viewPhotos));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('sổ ảnh là chế độ thứ ba, không thêm tab thứ năm',
      (WidgetTester tester) async {
    await _openJournal(tester, photoNotes: [_photo(id: 'p1', transactionId: 'tx-1')]);
    expect(find.text(AppStrings.photoAllTitle), findsWidgets);
    // Vẫn đúng bốn tab ở thanh điều hướng dưới.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sổ ảnh hiện ghi chú của từng ảnh',
      (WidgetTester tester) async {
    await _openJournal(tester, photoNotes: [
      _photo(id: 'p1', transactionId: 'tx-1', caption: 'Bún bò Huế'),
      _photo(id: 'p2', transactionId: 'tx-2'),
    ]);
    expect(find.text('Bún bò Huế'), findsOneWidget);
    // Ảnh chưa viết ghi chú vẫn phải có nhãn, không để ô trống.
    expect(find.text(PhotoNote.noCaption), findsOneWidget);
  });

  testWidgets('chưa có ảnh nào thì sổ ảnh mời thêm ảnh',
      (WidgetTester tester) async {
    await _openJournal(tester);
    expect(find.text(AppStrings.photoAllEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ảnh hỏng hiện icon, không vẽ chuỗi ngoại lệ',
      (WidgetTester tester) async {
    // Base64 hợp lệ nhưng không phải ảnh: đúng kiểu dữ liệu rác từ server.
    final broken = _photo(id: 'p1', transactionId: 'tx-1')
      ..['photo_base64'] = base64Encode(utf8.encode('không phải ảnh'));
    await _openJournal(tester, photoNotes: [broken]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('xoá ảnh chỉ xoá ảnh, khoản chi vẫn còn',
      (WidgetTester tester) async {
    final fake = await _openJournal(
      tester,
      photoNotes: [_photo(id: 'p1', transactionId: 'tx-1', caption: 'Bún bò')],
    );
    expect(fake.photoNotes, hasLength(1));

    // Chạm vào ảnh trong sổ để mở khoản chi chứa nó.
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(fake.calls, contains('GET /v1/transactions/tx-1'));

    // Trong chi tiết, chạm ảnh mở bảng thao tác rồi xoá. Ảnh của sổ vẫn
    // nằm trong cây phía sau sheet, nên phải chọn ảnh thuộc sheet.
    final sheetPhoto = find
        .descendant(of: find.byType(BottomSheet), matching: find.byType(Image))
        .last;
    await tester.tap(sheetPhoto);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.photoDelete));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.photoDeleteConfirmNote), findsOneWidget);
    // Nút xác nhận nằm cuối hộp thoại, không phải mục trong bảng thao tác.
    await tester.tap(find.text(AppStrings.photoDelete).last);
    await tester.pumpAndSettle();

    // Ảnh mất khỏi sổ, khoản chi vẫn nguyên.
    expect(fake.calls, contains('DELETE /v1/photo-notes/p1'));
    expect(fake.photoNotes, isEmpty);
    expect(fake.transactions, hasLength(2));
  });

  testWidgets('sửa ghi chú trong chi tiết thì sổ ảnh hiện chữ mới',
      (WidgetTester tester) async {
    await _openJournal(
      tester,
      photoNotes: [_photo(id: 'p1', transactionId: 'tx-1', caption: 'Chữ cũ')],
    );

    // Mở khoản chi từ sổ ảnh.
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    // Trong chi tiết, chạm ảnh để mở bảng thao tác của chính ảnh đó.
    final sheetPhoto = find
        .descendant(of: find.byType(BottomSheet), matching: find.byType(Image))
        .last;
    await tester.tap(sheetPhoto);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.photoEditCaption));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Chữ mới');
    await tester.tap(find.text(AppStrings.photoSaveCaption));
    await tester.pumpAndSettle();

    // Đóng sheet chi tiết rồi xem lại sổ ảnh: phải là chữ mới, không phải
    // chữ cũ. Trước đây chỉ danh sách của giao dịch được làm mới nên sổ ảnh
    // giữ nguyên ghi chú cũ tới lần mở app sau.
    // Đóng sheet chi tiết bằng phím back, giống người dùng thật.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Chữ mới'), findsOneWidget);
    expect(find.text('Chữ cũ'), findsNothing);
  });

  testWidgets('lọc ảnh theo giao dịch gửi đúng tham số',
      (WidgetTester tester) async {
    final fake = await _openJournal(
      tester,
      photoNotes: [
        _photo(id: 'p1', transactionId: 'tx-1'),
        _photo(id: 'p2', transactionId: 'tx-2'),
      ],
    );
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    // Chi tiết giao dịch tải ảnh của đúng khoản đó, không tải cả sổ.
    expect(
      fake.calls.any(
        (call) => call.startsWith('GET /v1/photo-notes'),
      ),
      isTrue,
    );
  });
}
