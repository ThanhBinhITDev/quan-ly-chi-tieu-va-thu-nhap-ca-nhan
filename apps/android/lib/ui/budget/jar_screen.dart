import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/providers.dart';
import 'package:android/ui/budget/jar_sheet.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Màn Chia hủ: chia ngân sách tháng thành từng hũ theo tỷ lệ phần trăm.
///
/// Khác tab Ngân sách ở chỗ: tab Ngân sách trả lời "hạn mức của tôi là bao
/// nhiêu, đã tiêu bao nhiêu", còn màn này trả lời "tôi muốn chia số tiền đó
/// ra sao". Hai câu hỏi khác nhau, nên hai màn hình khác nhau — nhồi chung sẽ
/// thành một danh sách dài không đọc nổi trên máy nhỏ.
class JarScreen extends ConsumerWidget {
  const JarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetJarsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.jarTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.jarAdd,
            onPressed: () => _openSheet(context, ref),
            icon: const Icon(LucideIcons.plus, size: 20),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(budgetJarsProvider),
          onSignOut: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
        data: (summary) {
          if (summary.isEmpty) return _EmptyJars(onCreate: () => _openSheet(context, ref));
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(budgetJarsProvider);
              await ref.read(budgetJarsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
                AppSpace.xxl,
              ),
              children: [
                _SplitCard(summary: summary),
                const SizedBox(height: AppSpace.lg),
                if (!summary.isEmpty && summary.budgetAmount == 0) ...[
                  _NoBudgetHint(
                    onSetBudget: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                for (var i = 0; i < summary.items.length; i++) ...[
                  _JarRow(
                    key: ValueKey('jar-row-${summary.items[i].id}'),
                    jar: summary.items[i],
                    colorIndex: i,
                    onTap: () => _openSheet(context, ref, jar: summary.items[i]),
                  ),
                  if (i != summary.items.length - 1)
                    const SizedBox(height: AppSpace.md),
                ],
                if (summary.unallocatedPct > 0) ...[
                  const SizedBox(height: AppSpace.md),
                  _UnallocatedRow(summary: summary),
                ],
                const SizedBox(height: AppSpace.xl),
                Text(
                  AppStrings.jarEmptyBody,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref, {
    BudgetJarDto? jar,
  }) async {
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    final saved = await showJarSheet(
      context,
      jar: jar,
      categories: categories.where((c) => c.type == 'expense').toList(),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(budgetJarsProvider);
    }
  }
}

/// Thẻ tổng: đã chia bao nhiêu %, còn bao nhiêu chưa chia, thành tiền.
class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.summary});

  final BudgetJarSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final hasBudget = summary.budgetAmount > 0;
    final ratio = (summary.allocatedPct / 100).clamp(0.0, 1.0);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasBudget
                ? formatMoney(summary.budgetAmount)
                : AppStrings.jarNoBudgetShort,
            style: TextStyle(
              fontSize: hasBudget ? 24 : 13,
              fontWeight: hasBudget ? FontWeight.w700 : FontWeight.w500,
              color: hasBudget ? AppColors.textPrimary : AppColors.warning,
              height: 1.35,
            ),
          ),
          if (hasBudget) ...[
            const SizedBox(height: AppSpace.xs),
            const Text(
              AppStrings.budgetSection,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: AppColors.neutralSoft,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              _Chip(
                label: AppStrings.jarAllocated(summary.allocatedPct),
                tone: AppColors.primary,
                soft: AppColors.primarySoft,
              ),
              if (summary.unallocatedPct > 0)
                _Chip(
                  label: AppStrings.jarUnallocated(summary.unallocatedPct),
                  tone: AppColors.warning,
                  soft: AppColors.warningSoft,
                ),
            ],
          ),
          if (hasBudget && summary.unallocatedPct > 0) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              formatMoney(summary.unallocatedAmount),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.tone, required this.soft});

  final String label;
  final Color tone;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          color: tone,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Một hũ: màu, tên, tỷ lệ, thanh tiến độ, số tiền còn lại.
class _JarRow extends StatelessWidget {
  const _JarRow({
    super.key,
    required this.jar,
    required this.colorIndex,
    required this.onTap,
  });

  final BudgetJarDto jar;
  final int colorIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = jarColor(jar.color, colorIndex);
    // Chưa gắn danh mục thì không quy được chi tiêu vào hũ: vẽ "0 / 800.000"
    // sẽ khiến người dùng tưởng mình chưa tiêu đồng nào, trong khi thật ra
    // app không biết. Nói rõ chưa theo dõi được thì đúng hơn.
    final hasAmount = jar.amount > 0 && jar.categoryIds.isNotEmpty;
    final spentRatio = jar.amount == 0
        ? 0.0
        : (jar.spent / jar.amount).clamp(0.0, 1.0);
    final barColor = switch (jar.status) {
      'exceeded' => AppColors.expense,
      'warning' => AppColors.warning,
      'notice' => AppColors.warning,
      _ => color,
    };

    return Semantics(
      button: true,
      label: '${jar.name}, ${jar.sharePct} phần trăm',
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
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      jar.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  // Cỡ chữ hệ thống lớn làm "45% ngân sách" rộng hơn cả hàng;
                  // cho co lại thay vì đẩy tên hũ ra ngoài khung.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        AppStrings.jarShareOfBudget(jar.sharePct),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              if (hasAmount) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: spentRatio,
                    minHeight: 6,
                    backgroundColor: AppColors.neutralSoft,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatMoney(jar.spent)} / ${formatMoney(jar.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Flexible(
                      child: Text(
                        jar.remaining >= 0
                            ? AppStrings.jarLeft(jar.remaining)
                            : AppStrings.jarOver(-jar.remaining),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: jar.remaining >= 0
                              ? AppColors.textSecondary
                              : AppColors.expense,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Text(
                  jar.categoryIds.isEmpty
                      ? AppStrings.jarNoCategorySpend
                      : AppStrings.jarSuggestCategory,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnallocatedRow extends StatelessWidget {
  const _UnallocatedRow({required this.summary});

  final BudgetJarSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.background,
      child: Row(
        children: [
          const Icon(
            LucideIcons.pieChart,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              AppStrings.jarUnallocated(summary.unallocatedPct),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (summary.unallocatedAmount > 0)
            Text(
              formatMoney(summary.unallocatedAmount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _NoBudgetHint extends StatelessWidget {
  const _NoBudgetHint({required this.onSetBudget});

  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.warningSoft,
      borderColor: AppColors.warningSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.alertCircle,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpace.sm),
              const Expanded(
                child: Text(
                  AppStrings.jarNoBudget,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.warning,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onSetBudget,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                minimumSize: const Size(48, 40),
                foregroundColor: AppColors.warning,
              ),
              child: const Text(
                AppStrings.jarNoBudgetAction,
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyJars extends StatelessWidget {
  const _EmptyJars({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.percent,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              AppStrings.jarEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            const Text(
              AppStrings.jarEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(AppStrings.jarCreate),
            ),
          ],
        ),
      ),
    );
  }
}

/// Màu hũ: ưu tiên màu người dùng chọn, không có thì lấy theo bảng màu.
Color jarColor(String? hex, int index) {
  if (hex != null && hex.length == 7 && hex.startsWith('#')) {
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return AppColors.chartPalette[index % AppColors.chartPalette.length];
}
