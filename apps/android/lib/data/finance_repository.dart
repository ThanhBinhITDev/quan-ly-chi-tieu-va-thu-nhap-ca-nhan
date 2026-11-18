import 'package:android/domain/finance_calculator.dart';
import 'package:android/domain/models.dart';

abstract class FinanceRepository {
  Future<DashboardData> getDashboard(DemoScenario scenario);

  Future<List<TransactionItem>> getTransactions(DemoScenario scenario);

  Future<List<BudgetItem>> getBudgets(DemoScenario scenario);

  Future<StatsData> getStats({
    required String range,
    required DemoScenario scenario,
  });
}

class FakeFinanceRepository implements FinanceRepository {
  FakeFinanceRepository({this.instant = false});

  final bool instant;

  final List<CategoryItem> _categories = const [
    CategoryItem(id: 'food', name: 'Ăn uống'),
    CategoryItem(id: 'travel', name: 'Đi lại'),
    CategoryItem(id: 'shopping', name: 'Mua sắm'),
    CategoryItem(id: 'study', name: 'Học tập'),
    CategoryItem(id: 'other', name: 'Khác'),
  ];

  Future<void> _delay() => instant
      ? Future<void>.value()
      : Future<void>.delayed(const Duration(milliseconds: 400));

  void _checkError(DemoScenario scenario) {
    if (scenario == DemoScenario.error) {
      throw Exception('Không thể tải dữ liệu. Vui lòng thử lại.');
    }
  }

  @override
  Future<DashboardData> getDashboard(DemoScenario scenario) async {
    await _delay();
    _checkError(scenario);
    if (scenario == DemoScenario.empty) {
      return DashboardData(
        summary: const MonthSummary(
          income: 0,
          expense: 0,
          balance: 0,
          dailyLimit: 0,
          budgetAmount: 0,
          daysLeft: 0,
          spent: 0,
        ),
        budgets: const [],
        recent: const [],
        syncStatus: SyncStatus.synced,
        isEmpty: true,
      );
    }
    const budget = 3000000;
    const spent = 1850000;
    const income = 3000000;
    const daysLeft = 18;
    return DashboardData(
      summary: MonthSummary(
        income: income,
        expense: spent,
        balance: remainingAmount(budget: income, spent: spent),
        dailyLimit: dailyLimit(
          budget: budget,
          spent: spent,
          daysLeft: daysLeft,
        ),
        budgetAmount: budget,
        daysLeft: daysLeft,
        spent: spent,
      ),
      budgets: _budgets(),
      recent: _transactions(),
      syncStatus: scenario == DemoScenario.offline
          ? SyncStatus.offline
          : SyncStatus.synced,
    );
  }

  @override
  Future<List<TransactionItem>> getTransactions(DemoScenario scenario) async {
    await _delay();
    _checkError(scenario);
    return scenario == DemoScenario.empty ? const [] : _transactions();
  }

  @override
  Future<List<BudgetItem>> getBudgets(DemoScenario scenario) async {
    await _delay();
    _checkError(scenario);
    return scenario == DemoScenario.empty ? const [] : _budgets();
  }

  @override
  Future<StatsData> getStats({
    required String range,
    required DemoScenario scenario,
  }) async {
    await _delay();
    _checkError(scenario);
    if (scenario == DemoScenario.empty) {
      return const StatsData(
        categories: [],
        daily: [],
        totalExpense: 0,
        comparisonPercent: 0,
        isEmpty: true,
      );
    }
    final factor = range == 'previous' ? 0.9 : 1.0;
    final categories = <CategoryTotal>[
      CategoryTotal(
        name: 'Ăn uống',
        amount: (980000 * factor).round(),
        percent: 53.0,
      ),
      CategoryTotal(
        name: 'Đi lại',
        amount: (320000 * factor).round(),
        percent: 17.3,
      ),
      CategoryTotal(
        name: 'Mua sắm',
        amount: (295000 * factor).round(),
        percent: 15.9,
      ),
      CategoryTotal(
        name: 'Khác',
        amount: (405000 * factor).round(),
        percent: 13.8,
      ),
    ];
    final daily = List<DayTotal>.generate(7, (index) {
      return DayTotal(
        label: 'N${index + 1}',
        amount: ((40000 + index * 9000) * factor).round(),
      );
    });
    return StatsData(
      categories: categories,
      daily: daily,
      totalExpense: categories.fold(0, (sum, item) => sum + item.amount),
      comparisonPercent: 18,
    );
  }

  List<BudgetItem> _budgets() {
    const rows = [
      (id: 'b1', name: 'Tổng tháng', limit: 3000000, spent: 1850000),
      (id: 'b2', name: 'Ăn uống', limit: 1500000, spent: 980000),
      (id: 'b3', name: 'Mua sắm', limit: 300000, spent: 295000),
    ];
    return rows.map((row) {
      return BudgetItem(
        id: row.id,
        name: row.name,
        limit: row.limit,
        spent: row.spent,
        remaining: remainingAmount(budget: row.limit, spent: row.spent),
        percent: spentPercent(spent: row.spent, limit: row.limit),
        periodLabel: '01/11 - 30/11',
      );
    }).toList();
  }

  List<TransactionItem> _transactions() => [
        TransactionItem(
          id: 't1',
          amount: 35000,
          type: TransactionType.expense,
          category: _categories[0],
          wallet: 'Tiền mặt',
          note: 'Cơm trưa',
          dayLabel: 'Hôm nay',
          pending: true,
        ),
        TransactionItem(
          id: 't2',
          amount: 7000,
          type: TransactionType.expense,
          category: _categories[1],
          wallet: 'Tiền mặt',
          note: 'Xe buýt',
          dayLabel: 'Hôm nay',
        ),
        TransactionItem(
          id: 't3',
          amount: 120000,
          type: TransactionType.income,
          category: _categories[4],
          wallet: 'VCB',
          note: 'Mẹ gửi',
          dayLabel: 'Hôm qua',
        ),
      ];
}
