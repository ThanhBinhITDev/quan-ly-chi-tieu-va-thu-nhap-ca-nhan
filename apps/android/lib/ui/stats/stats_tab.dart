import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/filter_chip.dart';
import 'package:android/ui/common/scenario_menu.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsProvider);
    final range = ref.watch(statsRangeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tabStats),
        actions: const [ScenarioMenu()],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(statsProvider),
        ),
        data: (data) {
          if (data.isEmpty) {
            return EmptyView(message: AppStrings.emptyStats);
          }
          final max = data.daily.fold<int>(
            1,
            (previous, item) => item.amount > previous ? item.amount : previous,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterChip(
                      label: AppStrings.rangeCurrent,
                      selected: range == 'current',
                      onSelected: () =>
                          ref.read(statsRangeProvider.notifier).select('current'),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    AppFilterChip(
                      label: AppStrings.rangePrevious,
                      selected: range == 'previous',
                      onSelected: () =>
                          ref.read(statsRangeProvider.notifier).select('previous'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: AppStrings.totalExpense,
                      value: formatMoney(data.totalExpense),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: SummaryCard(
                      title: AppStrings.comparePrevious,
                      value: '+${data.comparisonPercent}%',
                      emphasis: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                AppStrings.categories,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.md),
              CategoryDonutCard(categories: data.categories),
              const SizedBox(height: AppSpace.xl),
              Text(
                AppStrings.dailyTrend,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.md),
              SoftCard(
                child: Semantics(
                  label: AppStrings.chartSummaryPrefix,
                  child: Column(
                    children: data.daily.map((item) {
                      final ratio = item.amount / max;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                item.label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 10,
                                  backgroundColor: AppColors.neutralSoft,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            SizedBox(
                              width: 92,
                              child: Text(
                                formatMoney(item.amount),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
