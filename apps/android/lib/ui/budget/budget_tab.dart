import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/scenario_menu.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tabBudget),
        actions: const [ScenarioMenu()],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(budgetsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              message: AppStrings.emptyBudget,
              actionLabel: AppStrings.createBudget,
              onAction: () =>
                  ref.read(scenarioProvider.notifier).select(DemoScenario.ready),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
            itemBuilder: (context, index) {
              return BudgetTile(key: ValueKey(items[index].id), budget: items[index]);
            },
          );
        },
      ),
    );
  }
}
