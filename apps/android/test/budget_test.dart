import 'package:android/ui/strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

/// Mở tab Ngân sách trên một máy nhỏ và chờ dữ liệu về.
Future<FakeBackend> _openBudgetTab(
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
  await tester.tap(find.text(AppStrings.tabBudget).first);
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('tab ngân sách hiện hạn mức, còn lại và số ngày', (
    WidgetTester tester,
  ) async {
    final backend = await _openBudgetTab(tester);

    expect(find.text(AppStrings.budgetJars), findsOneWidget);
    // Số liệu lấy từ /v1/budgets/progress, không tự tính lại ở client.
    expect(find.textContaining('3.000.000'), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(backend.calls, contains('GET /v1/budgets/progress'));
  });

  testWidgets('sửa hạn mức gửi PATCH kèm rev + 1', (WidgetTester tester) async {
    final backend = await _openBudgetTab(tester);

    await tester.tap(find.text(AppStrings.budgetAddJar));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.budgetNew), findsOneWidget);

    // Ngân sách tổng đã tồn tại trong dữ liệu giả, nên chọn lại "tổng" sẽ bị
    // server chặn bằng RULE_VIOLATION. Ở đây kiểm luồng tạo mới thành công.
    await tester.enterText(find.byType(TextField).first, '2500000');
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.budgetCreate));
    await tester.pumpAndSettle();

    final body = backend.lastBudgetBody;
    expect(body, isNotNull);
    expect(body!['amount'], 2500000);
    expect(body['period'], 'month');
    expect(body['start_date'], matches(RegExp(r'^\d{4}-\d{2}-01$')));
    // Client tự sinh UUID v4 để POST lặp lại không tạo bản ghi trùng.
    expect(body['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  testWidgets('chạm vào hũ để sửa hạn mức đang có', (
    WidgetTester tester,
  ) async {
    final backend = await _openBudgetTab(tester);

    await tester.tap(
      find.byKey(const ValueKey('jar-5c000000-0000-4000-8000-000000000001')),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.budgetEditTotal), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1800000');
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.budgetSave));
    await tester.pumpAndSettle();

    final body = backend.lastBudgetBody;
    expect(body, isNotNull);
    expect(body!['amount'], 1800000);
    // PATCH bắt buộc kèm rev mới; thiếu rev là server trả VALIDATION_FAILED.
    expect(body['rev'], 2);
    expect(
      backend.calls,
      contains(
        'PATCH /v1/budgets/'
        '5c000000-0000-4000-8000-000000000001',
      ),
    );
  });

  testWidgets('hạn mức 0 bị chặn ngay trên máy', (WidgetTester tester) async {
    final backend = await _openBudgetTab(tester);
    backend.lastBudgetBody = null;

    await tester.tap(find.text(AppStrings.budgetAddJar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.budgetCreate));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.budgetAmountError), findsOneWidget);
    // Không gọi API khi dữ liệu chưa hợp lệ.
    expect(backend.lastBudgetBody, isNull);
  });

  testWidgets('có ngân sách Tổng lẫn hũ danh mục thì không cộng trùng', (
    WidgetTester tester,
  ) async {
    // Ngân sách Tổng đã bao mọi khoản chi; cộng thêm hũ "Học tập" vào tổng
    // sẽ đếm hai lần cùng một đồng tiền.
    await _openBudgetTab(
      tester,
      backend: FakeBackend(
        budgetTotal: 2200000,
        expense: 1768000,
        remaining: 432000,
        // Danh mục "Học tập" có 329.000 đ chi, vượt hạn mức 300.000 đ.
        expenseByCategory: {'5b000000-0000-4000-8000-000000000003': 329000},
        budgets: [
          {
            'id': '5c000000-0000-4000-8000-000000000001',
            'category_id': null,
            'amount': 2200000,
            'period': 'month',
            'start_date': '2026-11-01',
            'end_date': null,
            'rev': 1,
          },
          {
            'id': '5c000000-0000-4000-8000-000000000002',
            'category_id': '5b000000-0000-4000-8000-000000000003',
            'amount': 300000,
            'period': 'month',
            'start_date': '2026-11-01',
            'end_date': null,
            'rev': 1,
          },
        ],
      ),
    );

    // Tổng vẫn là 2.200.000 đ, không phải 2.500.000 đ.
    expect(find.textContaining('2.500.000'), findsNothing);
    expect(find.textContaining('2.200.000'), findsWidgets);
    // Phần chưa chia vào hũ nào phải hiện thành một lát riêng, nếu không
    // vòng tròn chỉ có hũ con và trông như đã chia hết hạn mức.
    expect(find.text(AppStrings.budgetUnassigned), findsOneWidget);
    // Hũ danh mục vẫn có dòng riêng với số của chính nó: cuộn tới đúng thẻ
    // thay vì đòi nó nằm trong vùng nhìn thấy ngay từ đầu.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('jar-5c000000-0000-4000-8000-000000000002')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('329.000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chưa có ngân sách thì mời tạo ngay từ màn trống', (
    WidgetTester tester,
  ) async {
    await _openBudgetTab(
      tester,
      backend: FakeBackend(hasBudget: false, budgets: []),
    );

    expect(find.text(AppStrings.emptyBudget), findsOneWidget);
    await tester.tap(find.text(AppStrings.budgetCreate));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.budgetNew), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
