import 'package:android/data/finance_repository.dart';
import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';
import 'package:android/main.dart';
import 'package:android/providers.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/transactions/add_transaction_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DemoModeOn extends DemoModeNotifier {
  @override
  bool build() => true;
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoModeProvider.overrideWith(_DemoModeOn.new),
        financeRepositoryProvider.overrideWithValue(
          FakeFinanceRepository(instant: true),
        ),
      ],
      child: const StudentFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.tabTransactions).first);
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
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
    await _pump(tester);
    await _openSheet(tester);

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(find.text('Nhập số tiền lớn hơn 0.'), findsOneWidget);
    expect(find.byType(AddTransactionSheet), findsOneWidget);
  });

  testWidgets('saved transaction appears in the list as pending',
      (tester) async {
    await _pump(tester);
    await _openSheet(tester);

    await tester.enterText(find.byType(TextFormField).first, '42000');
    await tester.tap(find.byType(DropdownButtonFormField<CategoryItem>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    expect(find.byType(AddTransactionSheet), findsNothing);
    expect(find.text('Ăn uống'), findsWidgets);
    expect(find.textContaining(AppStrings.pending), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
