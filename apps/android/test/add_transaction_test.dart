import 'package:android/domain/transaction_input.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/transactions/record_transaction_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

Future<FakeBackend> _pump(WidgetTester tester) async {
  final backend = FakeBackend();
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(testApp(backend));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.tabTransactions).first);
  await tester.pumpAndSettle();
  return backend;
}

Future<void> _openSheet(WidgetTester tester) async {
  // Shell mới bỏ FAB: tab "Thêm" ở giữa (index 2) mở màn ghi chép.
  await tester.tap(find.text(AppStrings.tabAdd));
  await tester.pumpAndSettle();
}

/// Nút Lưu nằm ở `bottomNavigationBar` nên luôn nhìn thấy; trước đây nó ở
/// cuối `ListView` và phải cuộn mới bấm được.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.recordSaveExpense));
  await tester.pumpAndSettle();
}

void main() {
  group('parseAmount', () {
    test('accepts plain and grouped numbers', () {
      expect(parseAmount('35000'), 35000);
      expect(parseAmount('35.000'), 35000);
      expect(parseAmount('35,000'), 35000);
      expect(parseAmount(' 1 200 '), 1200);
    });

    test('rejects empty, zero, negative and non-numeric input', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-5'), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });

  testWidgets('empty amount shows a validation error and does not save',
      (tester) async {
    final backend = await _pump(tester);
    await _openSheet(tester);

    await _tapSave(tester);

    expect(find.text(AppStrings.recordAmountError), findsOneWidget);
    expect(find.byType(RecordTransactionScreen), findsOneWidget);
    // Chưa gửi gì lên server: kiểm cả việc không có request thừa.
    expect(
      backend.calls.where((c) => c.startsWith('POST /v1/transactions')),
      isEmpty,
    );
  });

  testWidgets('saved transaction appears in the list', (tester) async {
    final backend = await _pump(tester);
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField).first, '42000');
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    expect(find.byType(RecordTransactionScreen), findsNothing);
    expect(find.text('Ăn uống'), findsWidgets);

    // Ghi đúng số tiền và đúng ví lên API, không chỉ hiện trên màn hình.
    final body = backend.lastTransactionBody;
    expect(body, isNotNull);
    expect(body!['amount'], 42000);
    expect(body['type'], 'expense');
    expect(body['wallet_id'], '5a000000-0000-4000-8000-000000000001');
    expect(body['category_id'], '5b000000-0000-4000-8000-000000000001');
    expect(backend.transactions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ví trống thì form nói rõ phải thêm ví trước', (tester) async {
    // Không có ví thì không thể ghi giao dịch: thông báo phải chỉ đúng việc
    // cần làm, không phải lỗi chung "lưu thất bại".
    final backend = FakeBackend(wallets: []);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(backend));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.tabTransactions).first);
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField).first, '42000');
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(find.text(AppStrings.pickWallet), findsWidgets);
    expect(backend.lastTransactionBody, isNull);
  });
}
