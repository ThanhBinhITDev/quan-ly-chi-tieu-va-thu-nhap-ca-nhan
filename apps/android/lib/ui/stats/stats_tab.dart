import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/filter_chip.dart';
import 'package:android/ui/common/scenario_menu.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/stats/charts.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Kiểu biểu đồ danh mục người dùng đang chọn. `null` = chưa chọn, dùng mặc
/// định theo bề rộng màn hình.
final categoryChartStyleProvider =
    NotifierProvider<CategoryChartStyleNotifier, CategoryChartStyle?>(
  CategoryChartStyleNotifier.new,
);

class CategoryChartStyleNotifier extends Notifier<CategoryChartStyle?> {
  @override
  CategoryChartStyle? build() => null;

  void select(CategoryChartStyle? style) => state = style;
}

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
          // Bộ chọn kỳ luôn hiển thị, kể cả khi kỳ đang xem trống. Nếu ẩn
          // theo EmptyView thì chọn "Tháng trước" xong người dùng bị kẹt
          // luôn ở tháng trống, không có đường quay lại "Tháng này".
          final chips = SingleChildScrollView(
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
          );

          if (data.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.sm,
                    AppSpace.lg,
                    0,
                  ),
                  child: Align(alignment: Alignment.centerLeft, child: chips),
                ),
                Expanded(
                  child: EmptyView(
                    message: range == 'previous'
                        ? AppStrings.emptyStatsPrevious
                        : AppStrings.emptyStats,
                    actionLabel: range == 'previous'
                        ? AppStrings.backToCurrentMonth
                        : null,
                    onAction: range == 'previous'
                        ? () => ref
                            .read(statsRangeProvider.notifier)
                            .select('current')
                        : null,
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            children: [
              Align(alignment: Alignment.centerLeft, child: chips),
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
                    child: _DeltaCard(
                      percent: data.comparisonPercent,
                      previousExpense: data.previousExpense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              _SectionHeader(
                title: AppStrings.categories,
                trailing: ChartStyleSwitcher(
                  value: ref.watch(categoryChartStyleProvider) ??
                      _defaultStyle(context),
                  onChanged: (style) => ref
                      .read(categoryChartStyleProvider.notifier)
                      .select(style),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                child: (ref.watch(categoryChartStyleProvider) ??
                            _defaultStyle(context)) ==
                        CategoryChartStyle.donut
                    ? CategoryDonutCard(
                        key: const ValueKey('donut'),
                        categories: data.categories,
                      )
                    : SoftCard(
                        key: const ValueKey('bars'),
                        child: CategoryBarChart(categories: data.categories),
                      ),
              ),
              const SizedBox(height: AppSpace.xl),
              _SectionHeader(title: AppStrings.dailyTrend),
              const SizedBox(height: AppSpace.md),
              SoftCard(
                child: data.daily.length < 2
                    ? _SingleDayNote(daily: data.daily)
                    : DailyTrendChart(daily: data.daily),
              ),
              if (data.daily.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                _PeakDayNote(daily: data.daily),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Màn hình hẹp dùng cột (đọc số dễ hơn), rộng thì dùng vòng.
  CategoryChartStyle _defaultStyle(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 420
        ? CategoryChartStyle.bars
        : CategoryChartStyle.donut;
  }
}

/// Thẻ so sánh với kỳ trước, có mũi tên chỉ chiều tăng/giảm.
class _DeltaCard extends StatelessWidget {
  const _DeltaCard({this.percent, this.previousExpense});

  /// `null` = tháng trước chưa có khoản chi nào, chưa tính được % thay đổi.
  final int? percent;

  /// Chi tiêu kỳ trước, hiện nhỏ bên dưới để người dùng đối chiếu con số.
  final int? previousExpense;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    if (value == null) {
      // Đừng hiện "0%" khi thật ra không có dữ liệu — người dùng sẽ tưởng
      // chi tiêu không đổi trong khi thực tế tháng trước trống.
      return Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.neutralSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.comparePrevious,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.compareNoBaseline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              AppStrings.compareNoBaselineNote,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final increased = value > 0;
    final unchanged = value == 0;
    final color = unchanged
        ? AppColors.textSecondary
        : (increased ? AppColors.expense : AppColors.income);
    final background = unchanged
        ? AppColors.neutralSoft
        : (increased ? AppColors.expenseSoft : AppColors.incomeSoft);
    final icon = unchanged
        ? LucideIcons.minus
        : (increased ? LucideIcons.trendingUp : LucideIcons.trendingDown);
    final previous = previousExpense;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.comparePrevious,
            style: TextStyle(fontSize: 12, color: color),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  unchanged
                      ? AppStrings.sameAsPrevious
                      : '${increased ? '+' : ''}$value%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (previous != null) ...[
            const SizedBox(height: 2),
            Text(
              AppStrings.previousExpenseAmount(formatMoney(previous)),
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Khi chỉ có một ngày dữ liệu, biểu đồ đường chỉ là một điểm — nói thẳng
/// thay vì vẽ một khung trống khó hiểu.
class _SingleDayNote extends StatelessWidget {
  const _SingleDayNote({required this.daily});

  final List<DayTotal> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const Text(AppStrings.emptyStats);
    }
    final item = daily.first;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.calendarDays,
            size: 18,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney(item.amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ngày chi nhiều nhất — thông tin hữu ích nhất khi nhìn biểu đồ.
class _PeakDayNote extends StatelessWidget {
  const _PeakDayNote({required this.daily});

  final List<DayTotal> daily;

  @override
  Widget build(BuildContext context) {
    var peak = daily.first;
    for (final item in daily) {
      if (item.amount > peak.amount) peak = item;
    }
    if (peak.amount == 0) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(
          LucideIcons.flame,
          size: 16,
          color: AppColors.warning,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Chi nhiều nhất: ${peak.label} · ${formatMoney(peak.amount)}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
