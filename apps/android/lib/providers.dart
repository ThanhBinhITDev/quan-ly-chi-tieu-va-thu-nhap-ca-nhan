import 'package:android/data/api_finance_repository.dart';
import 'package:android/data/finance_repository.dart';
import 'package:android/domain/models.dart';
import 'package:android/core/config/app_config.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/ui/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chế độ xem thử giao diện không cần mạng.
///
/// Mặc định **tắt**: app luôn mở ở màn hình đăng nhập để dùng tài khoản thật.
/// Chỉ bật khi dev truyền `--dart-define=DEMO_MODE=true`, hoặc khi người dùng
/// tự bấm "Xem thử không cần đăng nhập" ở màn hình đăng nhập.
final demoModeProvider = NotifierProvider<DemoModeNotifier, bool>(
  DemoModeNotifier.new,
);

class DemoModeNotifier extends Notifier<bool> {
  @override
  bool build() => AppConfig.demoMode;

  void setDemo(bool value) => state = value;
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final demo = ref.watch(demoModeProvider);
  final signedIn = ref.watch(isSignedInProvider);
  if (demo || !signedIn) return FakeFinanceRepository();
  return ApiFinanceRepository(ref.watch(financeApiProvider));
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

/// Danh mục cho form nhập liệu. Với repository mạng, phải nạp từ API trước.
final categoriesProvider = FutureProvider<List<CategoryItem>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  if (repo is ApiFinanceRepository) await repo.warmUp();
  return repo.categories;
});

/// Ví cho form nhập liệu. Demo không có ví thật nên dùng danh sách cố định.
final walletNamesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  if (repo is ApiFinanceRepository) {
    await repo.warmUp();
    final names = repo.wallets;
    if (names.isNotEmpty) return names;
  }
  return const [AppStrings.walletCash, AppStrings.walletBank];
});

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
