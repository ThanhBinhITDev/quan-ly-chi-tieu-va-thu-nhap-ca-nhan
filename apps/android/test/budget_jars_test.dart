import 'package:android/data/remote/dto.dart';
import 'package:android/ui/budget/jar_screen.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_backend.dart';

const _foodCategory = '5b000000-0000-4000-8000-000000000001';

Map<String, dynamic> _jar({
  String id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  String name = 'Ăn uống',
  int share = 40,
  List<String> categoryIds = const [_foodCategory],
  String? color,
  int rev = 1,
}) => {
      'id': id,
      'name': name,
      'share_pct': share,
      'category_ids': categoryIds,
      'color': color,
      'rev': rev,
    };


/// Mở app bằng máy chủ giả rồi vào tab Ngân sách — nơi có nút mở màn Chia hủ.
Future<void> _pump(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(testApp(backend));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.tabAccount).last);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(AppStrings.tabBudget).last);
  await tester.pumpAndSettle();
}

void main() {
  group('đọc JSON hũ', () {
    test('thiếu số liệu tiến độ thì mặc định về 0, không ném lỗi', () {
      // Danh sách hũ (GET /v1/budget-jars) không kèm amount/spent. Nếu fromJson
      // bắt buộc các khoá đó, màn hình sẽ trắng vì một trường không dùng tới.
      final jar = BudgetJarDto.fromJson(_jar());
      expect(jar.name, 'Ăn uống');
      expect(jar.sharePct, 40);
      expect(jar.amount, 0);
      expect(jar.spent, 0);
      expect(jar.usedPct, 0);
      expect(jar.status, 'ok');
      expect(jar.hasProgress, isFalse);
    });

    test('category_ids thiếu thì là mảng rỗng, không null', () {
      final jar = BudgetJarDto.fromJson({
        'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'name': 'Để dành',
        'share_pct': 20,
        'rev': 1,
      });
      expect(jar.categoryIds, isEmpty);
    });

    test('tổng quan đọc đúng phần chưa chia', () {
      final summary = BudgetJarSummaryDto.fromJson({
        'as_of': '2026-11-22',
        'budget_amount': 3000000,
        'allocated_pct': 60,
        'unallocated_pct': 40,
        'unallocated_amount': 1200000,
        'total_spent': 500000,
        'items': <Object>[],
      });
      expect(summary.budgetAmount, 3000000);
      expect(summary.unallocatedAmount, 1200000);
      expect(summary.isEmpty, isTrue);
    });
  });

  group('màu hũ', () {
    test('dùng màu người dùng chọn', () {
      expect(jarColor('#D13B3B', 0), const Color(0xFFD13B3B));
    });

    test('màu sai định dạng thì lấy theo bảng màu, không vỡ', () {
      expect(jarColor('red', 0), AppColors.chartPalette[0]);
      expect(jarColor('#12345', 1), AppColors.chartPalette[1]);
      expect(jarColor('#GGGGGG', 2), AppColors.chartPalette[2]);
    });

    test('không có màu thì xoay vòng bảng màu, không tràn chỉ số', () {
      // Danh sách dài hơn bảng màu không được ném RangeError.
      final long = AppColors.chartPalette.length + 3;
      expect(jarColor(null, long), AppColors.chartPalette[long % AppColors.chartPalette.length]);
    });
  });

  group('màn Chia hủ', () {
    testWidgets('chưa có hũ thì mời chia hũ đầu tiên', (tester) async {
      final backend = FakeBackend();
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.jarEmptyTitle), findsOneWidget);
      expect(find.text(AppStrings.jarCreate), findsOneWidget);
    });

    testWidgets('có hũ thì hiện tên, tỷ lệ và số tiền theo ngân sách tháng',
        (tester) async {
      final backend = FakeBackend(
        budgetTotal: 3000000,
        expenseByCategory: {_foodCategory: 900000},
        budgetJars: [_jar()],
      );
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();

      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text(AppStrings.jarShareOfBudget(40)), findsOneWidget);
      // 40% của 3.000.000 = 1.200.000, đã tiêu 900.000.
      expect(find.textContaining('1.200.000'), findsWidgets);
      expect(find.textContaining('900.000'), findsWidgets);
    });

    testWidgets('hũ vượt hạn mức thì hiện "Vượt" chứ không hiện số âm',
        (tester) async {
      final backend = FakeBackend(
        budgetTotal: 1000000,
        expenseByCategory: {_foodCategory: 600000},
        budgetJars: [_jar(share: 50)],
      );
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();

      // Hạn mức 500.000, tiêu 600.000 → vượt 100.000.
      expect(find.textContaining('Vượt'), findsOneWidget);
      expect(find.textContaining('-100.000'), findsNothing);
    });

    testWidgets('chưa đặt ngân sách tháng thì nói rõ, không hiện 0 đồng',
        (tester) async {
      final backend = FakeBackend(
        hasBudget: false,
        budgets: [],
        budgetJars: [_jar()],
      );
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.jarNoBudget), findsOneWidget);
    });

    testWidgets('hũ chưa gắn danh mục thì giải thích vì sao chưa có số',
        (tester) async {
      final backend = FakeBackend(
        budgetTotal: 2000000,
        budgetJars: [_jar(categoryIds: const [])],
      );
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.jarNoCategorySpend), findsOneWidget);
    });
  });

  group('tạo hũ qua giao diện', () {
    testWidgets('lưu hũ mới thì gửi đúng dữ liệu và danh sách có hũ đó',
        (tester) async {
      final backend = FakeBackend(budgetTotal: 3000000);
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.jarCreate));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarNameLabel),
        'Đi lại',
      );
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarShareLabel),
        '15',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.jarSave));
      await tester.pumpAndSettle();

      final body = backend.lastJarBody!;
      expect(body['name'], 'Đi lại');
      expect(body['share_pct'], 15);
      // id do client sinh để gọi lại không tạo hũ trùng.
      expect(body['id'], isA<String>());
      expect((body['id'] as String).length, 36);
      expect(find.text('Đi lại'), findsWidgets);
    });

    testWidgets('tên rỗng thì chặn tại chỗ, không gọi máy chủ', (tester) async {
      final backend = FakeBackend();
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.jarCreate));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarShareLabel),
        '20',
      );
      await tester.tap(find.text(AppStrings.jarSave));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.jarNameEmpty), findsOneWidget);
      expect(backend.lastJarBody, isNull);
    });

    testWidgets('tỷ lệ 0 thì chặn tại chỗ', (tester) async {
      final backend = FakeBackend();
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.jarCreate));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarNameLabel),
        'Thử',
      );
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarShareLabel),
        '0',
      );
      await tester.tap(find.text(AppStrings.jarSave));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.jarShareInvalid), findsOneWidget);
      expect(backend.lastJarBody, isNull);
    });

    testWidgets('tổng vượt 100% thì hiện lời giải thích của máy chủ',
        (tester) async {
      final backend = FakeBackend(
        budgetJars: [_jar(share: 90)],
      );
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.jarAdd));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarNameLabel),
        'Đi lại',
      );
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarShareLabel),
        '20',
      );
      await tester.tap(find.text(AppStrings.jarSave));
      await tester.pumpAndSettle();

      // 90 + 20 = 110 > 100: máy chủ chặn, app phải nói vì sao.
      expect(find.text(AppStrings.jarShareOver), findsOneWidget);
      expect(find.text(AppStrings.jarAdd), findsNothing);
    });
  });

  group('sửa và xoá hũ', () {
    testWidgets('sửa tỷ lệ thì PATCH kèm rev mới', (tester) async {
      final backend = FakeBackend(budgetJars: [_jar(share: 40)]);
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.jarShareLabel),
        '25',
      );
      await tester.tap(find.text(AppStrings.jarSave));
      await tester.pumpAndSettle();

      final body = backend.lastJarBody!;
      expect(body['share_pct'], 25);
      // rev phải là rev hiện tại + 1, nếu không server trả SYNC_CONFLICT.
      expect(body['rev'], 2);
    });

    testWidgets('xoá hũ phải xác nhận rồi mới gọi máy chủ', (tester) async {
      final backend = FakeBackend(budgetJars: [_jar()]);
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, AppStrings.jarDelete));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.jarDeleteConfirm), findsOneWidget);

      // Bấm Huỷ thì không xoá gì.
      await tester.tap(find.text(AppStrings.cancelLabel));
      await tester.pumpAndSettle();
      expect(backend.lastJarBody, isNull);
      expect(backend.budgetJars, hasLength(1));
    });

    testWidgets('đồng ý xoá thì gửi DELETE kèm rev', (tester) async {
      final backend = FakeBackend(budgetJars: [_jar(rev: 3)]);
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, AppStrings.jarDelete));
      await tester.pumpAndSettle();
      // Nút xác nhận trong hộp thoại cũng mang nhãn "Xoá hũ".
      await tester.tap(
        find.widgetWithText(TextButton, AppStrings.jarDeleteConfirmAction),
      );
      await tester.pumpAndSettle();

      expect(backend.lastJarBody!['rev'], '4');
      expect(backend.budgetJars, isEmpty);
    });

    testWidgets('lỗi máy chủ khi xoá thì ở lại sheet và báo lỗi',
        (tester) async {
      final backend = FakeBackend(budgetJars: [_jar()]);
      await _pump(tester, backend);

      await tester.tap(find.byTooltip(AppStrings.jarTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống'));
      await tester.pumpAndSettle();

      backend.failAll = true;
      await tester.tap(find.widgetWithText(TextButton, AppStrings.jarDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, AppStrings.jarDeleteConfirmAction),
      );
      await tester.pumpAndSettle();

      // Không được đóng sheet khi xoá thất bại: người dùng cần thấy lỗi.
      expect(find.text(AppStrings.jarSave), findsOneWidget);
    });
  });
}
