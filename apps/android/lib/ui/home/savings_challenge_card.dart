import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/core/session/auth_controller.dart';
import 'package:android/core/utils/uuid.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/domain/transaction_input.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Thẻ "Thử thách tiết kiệm": mục tiêu đầu tiên chưa hoàn thành, thanh tiến
/// trình, và nút thêm tiền vào mục tiêu đó.
///
/// Lỗi tải mục tiêu không được làm hỏng trang chủ: thẻ chỉ ẩn đi.
class SavingsChallengeCard extends ConsumerWidget {
  const SavingsChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).value;
    if (goals == null) return const SizedBox.shrink();

    final active = goals.where((g) => !g.isCompleted).toList();
    if (active.isEmpty) {
      return _NoGoalCard(hasCompleted: goals.isNotEmpty);
    }
    final goal = active.first;
    final pct = (goal.progressPct / 100).clamp(0, 1).toDouble();

    return SoftCard(
      child: Semantics(
        label: '${AppStrings.savingsChallenge}: ${goal.name}, '
            '${AppStrings.savingsSaved} ${formatMoney(goal.savedAmount)} / '
            '${formatMoney(goal.targetAmount)} '
            '(${formatPercent(goal.progressPct)})',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    LucideIcons.trophy,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    AppStrings.savingsChallenge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Nút gọn: 294px bề ngang ở máy 360dp không đủ cho
                // padding mặc định của TextButton cộng tiêu đề dài.
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _openAddAmount(context, ref, goal),
                  child: const Text(
                    AppStrings.savingsAddAmount,
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              goal.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.neutralSoft,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatMoney(goal.savedAmount)} / '
                    '${formatMoney(goal.targetAmount)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  formatPercent(goal.progressPct),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${AppStrings.savingsMissing} ${formatMoney(goal.missing)}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openAddAmount(
    BuildContext context,
    WidgetRef ref,
    GoalDto goal,
  ) async {
    final added = await showDialog<int>(
      context: context,
      builder: (_) => _AddAmountDialog(goal: goal),
    );
    if (added == null || !context.mounted) return;
    try {
      await ref.read(financeApiProvider).updateGoal(goal.id, {
        'rev': goal.rev + 1,
        'saved_amount': goal.savedAmount + added,
      });
      ref.invalidate(goalsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.savingsAdded} ${formatMoney(added)}'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

/// Chưa có mục tiêu: mời tạo, vì đây là tính năng người dùng không tự đoán ra.
class _NoGoalCard extends ConsumerWidget {
  const _NoGoalCard({required this.hasCompleted});

  final bool hasCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              LucideIcons.trophy,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.savingsChallenge,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasCompleted
                      ? AppStrings.savingsDone
                      : AppStrings.savingsEmpty,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          TextButton(
            onPressed: () => _openCreate(context, ref),
            child: const Text(AppStrings.savingsCreate),
          ),
        ],
      ),
    );
  }

  static Future<void> _openCreate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final draft = await showDialog<_GoalDraft>(
      context: context,
      builder: (_) => const _CreateGoalDialog(),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(financeApiProvider).createGoal({
        'id': generateUuidV4(),
        'name': draft.name,
        'target_amount': draft.targetAmount,
        'icon': 'trophy',
      });
      ref.invalidate(goalsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _GoalDraft {
  const _GoalDraft({required this.name, required this.targetAmount});

  final String name;
  final int targetAmount;
}

class _CreateGoalDialog extends StatefulWidget {
  const _CreateGoalDialog();

  @override
  State<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<_CreateGoalDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppStrings.savingsNameError);
      return;
    }
    final amount = parseAmount(_amountController.text);
    if (amount == null) {
      setState(() => _error = AppStrings.savingsTargetError);
      return;
    }
    Navigator.of(context).pop(
      _GoalDraft(name: name, targetAmount: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.savingsNewTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: AppStrings.savingsNameLabel,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: AppStrings.savingsTargetLabel,
              suffixText: 'đ',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.expense, fontSize: 12.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(AppStrings.savingsCreate),
        ),
      ],
    );
  }
}

class _AddAmountDialog extends StatefulWidget {
  const _AddAmountDialog({required this.goal});

  final GoalDto goal;

  @override
  State<_AddAmountDialog> createState() => _AddAmountDialogState();
}

class _AddAmountDialogState extends State<_AddAmountDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmount(_controller.text);
    if (amount == null) {
      setState(() => _error = AppStrings.savingsTargetError);
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.goal.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${AppStrings.savingsSaved} ${formatMoney(widget.goal.savedAmount)}'
            ' / ${formatMoney(widget.goal.targetAmount)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: AppStrings.savingsAmountLabel,
              suffixText: 'đ',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.expense, fontSize: 12.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(AppStrings.savingsAddConfirm),
        ),
      ],
    );
  }
}
