
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/core/error/app_exception.dart';
import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/common/transaction_photos.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';
import 'package:android/ui/transactions/record_transaction_screen.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.color = AppColors.surface,
    this.borderColor = AppColors.divider,
    this.radius = AppRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class HeroBalanceCard extends StatelessWidget {
  const HeroBalanceCard({super.key, required this.summary});

  final MonthSummary summary;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDark],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Semantics(
        label:
            '${AppStrings.balance}: ${formatMoney(summary.balance)}. '
            '${AppStrings.income}: ${formatMoney(summary.income)}. '
            '${AppStrings.expense}: ${formatMoney(summary.expense)}',
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.balance,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.wallet,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoney(summary.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: _HeroAmount(
                      icon: LucideIcons.trendingUp,
                      label: AppStrings.income,
                      value: formatMoney(summary.income),
                    ),
                  ),
                  const SizedBox(width: AppSpace.xl),
                  Expanded(
                    child: _HeroAmount(
                      icon: LucideIcons.trendingDown,
                      label: AppStrings.expense,
                      value: formatMoney(summary.expense),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PredictionCard extends StatelessWidget {
  const PredictionCard({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Semantics(
        label:
            '${AppStrings.predictionTitle} ${summary.daysLeft} '
            '${AppStrings.predictionDays}. '
            '${AppStrings.todayLimit}: ${formatMoney(summary.dailyLimit)}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.sparkles,
                color: AppColors.primaryDark,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.predictionTitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${summary.daysLeft} ',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        AppStrings.predictionDays,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      text: '${AppStrings.todayLimit}: ',
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: formatMoney(summary.dailyLimit),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
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
      ),
    );
  }
}

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({super.key, required this.budget});

  final BudgetItem budget;

  @override
  Widget build(BuildContext context) {
    final isHigh = budget.percent >= 90;
    final isMedium = budget.percent >= 70 && !isHigh;
    final tagColor = isHigh || isMedium ? AppColors.warning : AppColors.primaryDark;
    final tagBackground =
        isHigh || isMedium ? AppColors.warningSoft : AppColors.primarySoft;
    final barColor = isHigh
        ? AppColors.expense
        : isMedium
            ? AppColors.warning
            : AppColors.primary;

    return SoftCard(
      child: Semantics(
        label:
            '${AppStrings.monthBudget}: ${formatMoney(budget.spent)} / '
            '${formatMoney(budget.limit)} (${formatPercent(budget.percent)})',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.monthBudget,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagBackground,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    formatPercent(budget.percent),
                    style: TextStyle(
                      color: tagColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.md,
              runSpacing: 4,
              children: [
                Text(
                  '${formatMoney(budget.spent)} / ${formatMoney(budget.limit)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${AppStrings.budgetRemaining} ${formatMoney(budget.remaining)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (budget.percent / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.neutralSoft,
                color: barColor,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              budget.periodLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetTile extends StatelessWidget {
  const BudgetTile({super.key, required this.budget});

  final BudgetItem budget;

  @override
  Widget build(BuildContext context) {
    final isHigh = budget.percent >= 90;
    final isMedium = budget.percent >= 70 && !isHigh;
    final barColor = isHigh
        ? AppColors.expense
        : isMedium
            ? AppColors.warning
            : AppColors.primary;

    return SoftCard(
      child: Semantics(
        label:
            '${budget.name}: ${AppStrings.budgetUsed} ${formatMoney(budget.spent)} / '
            '${formatMoney(budget.limit)} (${formatPercent(budget.percent)})',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.neutralSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.target,
                    color: AppColors.textPrimary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        budget.periodLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text(
                  formatPercent(budget.percent),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isHigh
                        ? AppColors.expense
                        : isMedium
                            ? AppColors.warning
                            : AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              '${formatMoney(budget.spent)} / ${formatMoney(budget.limit)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (budget.percent / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.neutralSoft,
                color: barColor,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              '${AppStrings.budgetRemaining}: ${formatMoney(budget.remaining)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item});

  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final background =
        isIncome ? AppColors.incomeSoft : AppColors.expenseSoft;
    final icon = isIncome
        ? LucideIcons.trendingUp
        : LucideIcons.trendingDown;
    final sign = isIncome ? '+' : '-';
    final detailParts = <String>[
      item.dayLabel,
      if (item.wallet.isNotEmpty) item.wallet,
      if (item.paymentMethod != null)
        AppStrings.paymentMethodLabel(item.paymentMethod),
      if (item.note.isNotEmpty) item.note,
    ];

    return Semantics(
      button: true,
      label: '${item.category.name} $sign${formatMoney(item.amount)}, '
          '${detailParts.join(' · ')}'
          '${item.pending ? ' (chờ đồng bộ)' : ''}',
      child: InkWell(
        onTap: () => showTransactionDetail(context, item),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detailParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (item.hasReceipt) ...[
                const SizedBox(width: AppSpace.xs),
                const Icon(LucideIcons.camera, size: 14, color: AppColors.textSecondary),
              ],
              const SizedBox(width: AppSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$sign${formatMoney(item.amount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (item.pending) ...[
                    const SizedBox(height: 4),
                    const PendingLabel(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showTransactionDetail(BuildContext context, TransactionItem item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TransactionDetailSheet(item: item),
  );
}

/// Chi tiết giao dịch.
///
/// Danh sách giao dịch cố tình không kèm ảnh kỷ niệm (50 dòng × 512KB sẽ
/// thành chục MB mỗi lần mở tab), nên ảnh chỉ được tải khi mở sheet này.
class _TransactionDetailSheet extends ConsumerStatefulWidget {
  const _TransactionDetailSheet({required this.item});

  final TransactionItem item;

  @override
  ConsumerState<_TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<_TransactionDetailSheet> {

  Future<void> _edit(TransactionItem item) async {
    // Lấy container trước khi đóng sheet: sau `pop` State này bị hủy.
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).pop();
    final ok = await openRecordTransaction(context, editing: item);
    if (ok != true) return;
    container.invalidate(transactionsProvider);
    container.invalidate(dashboardProvider);
    container.invalidate(budgetProgressProvider);
  }

  Future<void> _delete(TransactionItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.txDeleteAction),
        content: const Text(AppStrings.txDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.txDeleteAction),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await container
          .read(financeRepositoryProvider)
          .deleteTransaction(item.id, rev: item.rev);
      container.invalidate(transactionsProvider);
      container.invalidate(dashboardProvider);
      container.invalidate(budgetProgressProvider);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.txDeleted)),
      );
    } catch (e) {
      // Trước đây lỗi xóa bị nuốt im lặng, sheet đóng mà dữ liệu vẫn còn.
      if (!mounted) return;
      final message = e is AppException ? e.message : AppStrings.txDeleteFailed;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isIncome = item.type == TransactionType.income;
    final sign = isIncome ? '+' : '-';
    final color = isIncome ? AppColors.income : AppColors.expense;
    final time = item.occurredAt;
    final timeLabel = time == null
        ? item.dayLabel
        : '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} '
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.txDetailTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                '$sign${formatMoney(item.amount)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              _detailRow(AppStrings.categoryLabel, item.category.name),
              _detailRow(AppStrings.walletLabel, item.wallet),
              _detailRow(AppStrings.txTimeLabel, timeLabel),
              _detailRow(
                AppStrings.recordPaymentMethod,
                AppStrings.paymentMethodLabel(item.paymentMethod),
              ),
              if (isIncome && (item.incomeSource ?? '').isNotEmpty)
                _detailRow(AppStrings.txIncomeSourceLabel, item.incomeSource!),
              if (item.note.isNotEmpty)
                _detailRow(AppStrings.noteLabel, item.note),
              const SizedBox(height: AppSpace.md),
              Text(
                AppStrings.photoSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.sm),
              TransactionPhotos(transactionId: item.id),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _edit(item),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      label: const Text(AppStrings.txEditAction),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.expense,
                      ),
                      onPressed: () => _delete(item),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text(AppStrings.txDeleteAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.emphasis = false,
  });

  final String title;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Semantics(
        label: '$title: $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpace.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: emphasis ? AppColors.primaryDark : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDonutCard extends StatelessWidget {
  const CategoryDonutCard({super.key, required this.categories});

  final List<CategoryTotal> categories;

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[
      for (var i = 0; i < categories.length; i++)
        PieChartSectionData(
          value: categories[i].amount.toDouble(),
          color: AppColors.chartPalette[i % AppColors.chartPalette.length],
          showTitle: false,
          radius: 28,
        ),
    ];
    final totalExpense = categories.fold(
      0,
      (sum, item) => sum + item.amount,
    );

    return SoftCard(
      child: Semantics(
        label:
            '${AppStrings.chartSummaryPrefix} '
            '${categories.map((item) => '${item.name}: ${formatMoney(item.amount)}').join('; ')}',
        child: Row(
          children: [
            SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 44,
                      sectionsSpace: 3,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.totalExpense,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatMoney(totalExpense),
                          style: const TextStyle(
                            fontSize: 13,
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
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < categories.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.chartPalette[i % AppColors.chartPalette.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  categories[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${formatPercent(categories[i].percent)} · ${formatMoney(categories[i].amount)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
            ),
          ],
        ),
      ),
    );
  }
}
