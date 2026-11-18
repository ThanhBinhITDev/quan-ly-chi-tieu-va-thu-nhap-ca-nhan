import 'package:android/data/finance_repository.dart';
import 'package:android/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FakeFinanceRepository();
});

class ScenarioNotifier extends Notifier<DemoScenario> {
  @override
  DemoScenario build() => DemoScenario.ready;

  void select(DemoScenario scenario) => state = scenario;
}

final scenarioProvider =
    NotifierProvider<ScenarioNotifier, DemoScenario>(ScenarioNotifier.new);

class RangeNotifier extends Notifier<String> {
  @override
  String build() => 'current';

  void select(String range) => state = range;
}

final statsRangeProvider = NotifierProvider<RangeNotifier, String>(
  RangeNotifier.new,
);

final dashboardProvider = FutureProvider<DashboardData>((ref) {
  final scenario = ref.watch(scenarioProvider);
  return ref.watch(financeRepositoryProvider).getDashboard(scenario);
});

final transactionsProvider = FutureProvider<List<TransactionItem>>((ref) {
  final scenario = ref.watch(scenarioProvider);
  return ref.watch(financeRepositoryProvider).getTransactions(scenario);
});

final budgetsProvider = FutureProvider<List<BudgetItem>>((ref) {
  final scenario = ref.watch(scenarioProvider);
  return ref.watch(financeRepositoryProvider).getBudgets(scenario);
});

final statsProvider = FutureProvider<StatsData>((ref) {
  final scenario = ref.watch(scenarioProvider);
  final range = ref.watch(statsRangeProvider);
  return ref.watch(financeRepositoryProvider).getStats(
        range: range,
        scenario: scenario,
      );
});
