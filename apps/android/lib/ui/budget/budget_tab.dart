import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/data/remote/dto.dart';
import 'package:android/ui/budget/budget_sheet.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Tab Ngân sách: tổng hạn mức tháng, vòng tròn phân bổ, từng hũ chi tiêu,
/// và một thẻ mẹo đọc từ chính số liệu vừa tải (không gọi AI, không bịa).
class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetProgressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tabBudget)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(budgetProgressProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              message: AppStrings.emptyBudget,
              actionLabel: AppStrings.budgetCreate,
              onAction: () => _openCreate(context, ref),
            );
          }
          // Ngân sách "Tổng" (categoryId == null) đã bao mọi khoản chi, nên
          // cộng thêm hũ danh mục vào nó là cộng trùng: hạn mức và chi tiêu
          // của tháng lấy theo ngân sách Tổng, chỉ khi không có Tổng mới cộng
          // các hũ (chúng là các danh mục rời nhau).
          BudgetProgressDto? overall;
          for (final item in items) {
            if (item.categoryId == null) {
              overall = item;
              break;
            }
          }
          final totalLimit =
              overall?.amount ?? items.fold<int>(0, (sum, b) => sum + b.amount);
          final totalSpent =
              overall?.spent ?? items.fold<int>(0, (sum, b) => sum + b.spent);
          final usedPct = totalLimit == 0
              ? 0.0
              : (totalSpent / totalLimit * 100).clamp(0, 100).toDouble();
          final daysLeft = items.first.daysLeft;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(budgetProgressProvider);
              await ref.read(budgetProgressProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
                AppSpace.xxl,
              ),
              children: [
                _BudgetTotalCard(
                  totalLimit: totalLimit,
                  totalSpent: totalSpent,
                  usedPct: usedPct,
                  daysLeft: daysLeft,
                ),
                const SizedBox(height: AppSpace.lg),
                _AllocationCard(
                  items: items,
                  totalLimit: totalLimit,
                  overall: overall,
                ),
                const SizedBox(height: AppSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.budgetJars,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openCreate(context, ref),
                      icon: const Icon(LucideIcons.plus, size: 15),
                      label: const Text(
                        AppStrings.budgetAddJar,
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                for (var i = 0; i < items.length; i++) ...[
                  _JarCard(
                    key: ValueKey('jar-${items[i].budgetId}'),
                    item: items[i],
                    colorIndex: i,
                    onTap: () => _openEdit(context, ref, items[i]),
                  ),
                  if (i != items.length - 1)
                    const SizedBox(height: AppSpace.md),
                ],
                const SizedBox(height: AppSpace.xl),
                _TipCard(
                  usedPct: usedPct,
                  daysLeft: daysLeft,
                  worst: _worstJar(items),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Mở sheet tạo ngân sách; danh mục đã có hạn mức thì mở thẳng chế độ sửa
  /// để người dùng không gặp lỗi `RULE_VIOLATION` ngay sau khi bấm Lưu.
  static Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    await showBudgetSheet(
      context,
      categories: categories.where((c) => c.type == 'expense').toList(),
    );
  }

  /// Mở sheet sửa hạn mức của một hũ.
  static Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref,
    BudgetProgressDto item,
  ) async {
    final active = await ref.read(activeBudgetsProvider.future);
    BudgetDto? existing;
    for (final budget in active) {
      if (budget.id == item.budgetId) {
        existing = budget;
        break;
      }
    }
    if (!context.mounted) return;
    if (existing == null) {
      // Ngân sách vừa bị xoá ở thiết bị khác: tải lại thay vì sửa bản cũ.
      ref.invalidate(budgetProgressProvider);
      return;
    }
    await showBudgetSheet(context, existing: existing);
  }

  static BudgetProgressDto? _worstJar(List<BudgetProgressDto> items) {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => b.usedPct >= a.usedPct ? b : a);
  }
}

/// Thẻ tổng: hạn mức tháng, đã dùng, còn lại, và số ngày còn lại.
class _BudgetTotalCard extends StatelessWidget {
  const _BudgetTotalCard({
    required this.totalLimit,
    required this.totalSpent,
    required this.usedPct,
    required this.daysLeft,
  });

  final int totalLimit;
  final int totalSpent;
  final double usedPct;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final remaining = totalLimit - totalSpent;
    final barColor = usedPct >= 90
        ? AppColors.expense
        : usedPct >= 70
        ? AppColors.warning
        : AppColors.primary;

    return SoftCard(
      color: AppColors.primaryDark,
      borderColor: AppColors.primaryDark,
      child: Semantics(
        label:
            '${AppStrings.budgetTotalMonth}: ${formatMoney(totalLimit)}. '
            '${AppStrings.budgetUsed} ${formatMoney(totalSpent)} '
            '(${formatPercent(usedPct)}). '
            '${AppStrings.budgetDaysLeft(daysLeft)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.budgetTotalMonth,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.walletMinimal,
                  size: 18,
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(totalLimit),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (usedPct / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: barColor == AppColors.primary ? Colors.white : barColor,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: _TotalStat(
                    label: AppStrings.budgetSpentLabel,
                    value: formatMoney(totalSpent),
                  ),
                ),
                Expanded(
                  child: _TotalStat(
                    label: AppStrings.budgetRemaining,
                    value: formatMoney(remaining < 0 ? 0 : remaining),
                  ),
                ),
                Expanded(
                  child: _TotalStat(
                    label: AppStrings.budgetDayUnit,
                    value: '$daysLeft',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalStat extends StatelessWidget {
  const _TotalStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Vòng tròn phân bổ theo từng hũ + chú giải %.
///
/// Có ngân sách "Tổng" thì đó là 100% và các hũ danh mục là phần đã chia
/// bên trong nó; phần còn lại là "Chưa chia". Không có ngân sách Tổng thì
/// các hũ danh mục là những khoản rời nhau và tự cộng thành 100%.
class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.items,
    required this.totalLimit,
    this.overall,
  });

  final List<BudgetProgressDto> items;
  final int totalLimit;

  /// Ngân sách "Tổng" nếu có: các hũ còn lại là phần chia trong nó.
  final BudgetProgressDto? overall;

  @override
  Widget build(BuildContext context) {
    // Hạn mức tổng thể = mẫu số của mọi tỉ lệ hiển thị ở thẻ này.
    final denominator = overall?.amount ?? totalLimit;

    // Vòng tròn chia theo HẠN MỨC phân bổ, đúng nghĩa "phân bổ"; chia theo
    // chi tiêu thực tế sẽ trùng số khi có cả ngân sách Tổng lẫn hũ.
    // Loại chính ngân sách Tổng khỏi danh sách hũ: nó là mẫu số, không phải
    // một phần được chia trong chính nó.
    final jars = items
        .where((b) => b.amount > 0 && b.budgetId != overall?.budgetId)
        .toList();
    final assigned = jars.fold<int>(0, (sum, b) => sum + b.amount);
    final unassigned = denominator - assigned;

    // Chưa chia hũ nào thì cả vòng tròn là ngân sách Tổng: hiện một lát
    // "Chưa chia 100%" ở đây chỉ làm người dùng tưởng còn việc phải làm.
    final slices = <({String name, int amount, Color color})>[
      if (overall != null && jars.isEmpty)
        (
          name: AppStrings.budgetScopeTotalShort,
          amount: denominator,
          color: AppColors.primary,
        )
      else ...[
        for (var i = 0; i < jars.length; i++)
          (
            name: jars[i].name,
            amount: jars[i].amount,
            color: AppColors.chartPalette[i % AppColors.chartPalette.length],
          ),
        if (overall != null && unassigned > 0)
          (
            name: AppStrings.budgetUnassigned,
            amount: unassigned,
            color: AppColors.neutralSoft,
          ),
      ],
    ];

    String share(int amount) => denominator <= 0
        ? formatPercent(0)
        : formatPercent(amount / denominator * 100);

    return SoftCard(
      child: Semantics(
        label:
            '${AppStrings.budgetAllocation}: '
            '${slices.map((s) => '${s.name} ${share(s.amount)}').join(', ')}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.budgetAllocation,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.md),
            if (slices.isEmpty)
              Text(
                AppStrings.budgetNothingSpent,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 118,
                    height: 118,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sections: [
                              for (final slice in slices)
                                PieChartSectionData(
                                  value: slice.amount.toDouble(),
                                  color: slice.color,
                                  showTitle: false,
                                  radius: 26,
                                ),
                            ],
                            centerSpaceRadius: 40,
                            sectionsSpace: 3,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppStrings.budgetAmountLabel,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatMoneyShort(denominator),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final slice in slices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: slice.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                    slice.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  share(slice.amount),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Một hũ chi tiêu: tên, đã dùng / hạn mức, thanh tiến trình theo màu hũ.
class _JarCard extends StatelessWidget {
  const _JarCard({
    super.key,
    required this.item,
    required this.colorIndex,
    required this.onTap,
  });

  final BudgetProgressDto item;
  final int colorIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOver = item.usedPct >= 100;
    final color = isOver
        ? AppColors.expense
        : AppColors.chartPalette[colorIndex % AppColors.chartPalette.length];

    // Cả thẻ là vùng chạm để sửa hạn mức; InkWell đặt trong Semantics để
    // trình đọc màn hình đọc một khối số liệu thay vì từng dòng rời.
    return Semantics(
      button: true,
      label:
          '${item.name}: ${AppStrings.budgetUsed} ${formatMoney(item.spent)} / '
          '${formatMoney(item.amount)} (${formatPercent(item.usedPct)})',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SoftCard(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(LucideIcons.target, size: 17, color: color),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatMoney(item.spent)} / ${formatMoney(item.amount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPercent(item.usedPct),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isOver ? AppColors.expense : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: (item.usedPct / 100).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: AppColors.neutralSoft,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ mẹo: câu kết luận suy ra từ số liệu thật, không phải AI.
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.usedPct,
    required this.daysLeft,
    required this.worst,
  });

  final double usedPct;
  final int daysLeft;
  final BudgetProgressDto? worst;

  @override
  Widget build(BuildContext context) {
    final String tip;
    if (usedPct >= 100) {
      tip = AppStrings.budgetTipOver;
    } else if (worst != null && worst!.usedPct >= 90) {
      tip = AppStrings.budgetTipOneJar(worst!.name);
    } else if (usedPct >= 70) {
      tip = AppStrings.budgetTipWatch;
    } else if (daysLeft <= 7 && usedPct < 50) {
      tip = AppStrings.budgetTipAlmostDone;
    } else {
      tip = AppStrings.budgetTipGood;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.lightbulb, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.budgetTipTitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
