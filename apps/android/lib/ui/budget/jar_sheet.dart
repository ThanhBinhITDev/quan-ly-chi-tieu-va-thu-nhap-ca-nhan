import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/core/error/app_exception.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/core/utils/uuid.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Sheet tạo mới hoặc sửa một hũ.
///
/// Tỷ lệ là số nguyên phần trăm của ngân sách tháng. Server chặn tổng vượt
/// 100%, nhưng sheet cũng tự tính phần còn chia được để người dùng thấy ngay
/// ngưỡng tối đa thay vì bấm Lưu rồi mới báo lỗi.
Future<bool?> showJarSheet(
  BuildContext context, {
  BudgetJarDto? jar,
  List<CategoryItem> categories = const [],
  int? prefillShare,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => JarSheet(
      jar: jar,
      categories: categories,
      prefillShare: prefillShare,
    ),
  );
}

class JarSheet extends ConsumerStatefulWidget {
  const JarSheet({
    super.key,
    this.jar,
    this.categories = const [],
    this.prefillShare,
  });

  final BudgetJarDto? jar;
  final List<CategoryItem> categories;
  final int? prefillShare;

  @override
  ConsumerState<JarSheet> createState() => _JarSheetState();
}

class _JarSheetState extends ConsumerState<JarSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _shareController;
  late Set<String> _categoryIds;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.jar != null;

  @override
  void initState() {
    super.initState();
    final jar = widget.jar;
    _nameController = TextEditingController(text: jar?.name ?? '');
    _shareController = TextEditingController(
      text: jar != null
          ? '${jar.sharePct}'
          : (widget.prefillShare == null ? '' : '${widget.prefillShare}'),
    );
    _categoryIds = {...?jar?.categoryIds};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shareController.dispose();
    super.dispose();
  }

  /// Tỷ lệ còn chia được: 100 trừ tổng các hũ khác (bỏ qua chính hũ đang sửa).
  int _remainingShare(BudgetJarSummaryDto summary) {
    var used = 0;
    for (final jar in summary.items) {
      if (jar.id == widget.jar?.id) continue;
      used += jar.sharePct;
    }
    return 100 - used;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppStrings.jarNameEmpty);
      return;
    }
    if (name.length > 40) {
      setState(() => _error = AppStrings.jarNameTooLong);
      return;
    }
    final share = int.tryParse(_shareController.text.trim());
    if (share == null || share < 1 || share > 100) {
      setState(() => _error = AppStrings.jarShareInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(financeApiProvider);
    try {
      if (_isEdit) {
        await api.updateBudgetJar(widget.jar!.id, {
          'rev': widget.jar!.rev + 1,
          'name': name,
          'share_pct': share,
          'category_ids': _categoryIds.toList(),
        });
      } else {
        await api.createBudgetJar({
          'id': generateUuidV4(),
          'name': name,
          'share_pct': share,
          // Đặt cuối danh sách: hũ mới thêm không nhảy lên đầu làm xô lệch
          // thứ tự người dùng đã quen.
          'sort_order':
              ref.read(budgetJarsProvider).value?.items.length ?? 0,
          'category_ids': _categoryIds.toList(),
        });
      }
      if (!mounted) return;
      ref.invalidate(budgetJarsProvider);
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error.code) {
          ApiErrorCode.ruleViolation => AppStrings.jarShareOver,
          ApiErrorCode.syncConflict => AppStrings.saveFailed,
          _ => error.message,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppStrings.saveFailed;
      });
    }
  }

  Future<void> _delete() async {
    final jar = widget.jar;
    if (jar == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.jarDelete),
        content: const Text(AppStrings.jarDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              AppStrings.jarDeleteConfirmAction,
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(financeApiProvider)
          .deleteBudgetJar(jar.id, rev: jar.rev + 1);
      if (!mounted) return;
      ref.invalidate(budgetJarsProvider);
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppStrings.saveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(budgetJarsProvider).value;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? AppStrings.jarEditTitle : AppStrings.jarNewTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (summary != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                AppStrings.jarRemaining(_remainingShare(summary)),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_isEdit,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: AppStrings.jarNameLabel,
                hintText: AppStrings.jarNameHint,
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _shareController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.jarShareLabel,
                suffixText: '%',
                helperText: _shareHint(summary),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (summary != null && summary.budgetAmount > 0) ...[
              const SizedBox(height: AppSpace.sm),
              _PreviewAmount(
                budgetAmount: summary.budgetAmount,
                shareText: _shareController.text,
              ),
            ],
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Text(
                AppStrings.jarCategoryLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              const Text(
                AppStrings.jarCategoryHint,
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final category in widget.categories)
                    _CategoryChip(
                      label: category.name,
                      selected: _categoryIds.contains(category.id),
                      onTap: () => setState(() {
                        if (_categoryIds.contains(category.id)) {
                          _categoryIds.remove(category.id);
                        } else {
                          _categoryIds.add(category.id);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.expense, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppStrings.jarSave),
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpace.sm),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  minimumSize: const Size(48, 44),
                ),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text(AppStrings.jarDelete),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Gợi ý tỷ lệ tối đa còn chia được, để người dùng không phải đoán.
  String? _shareHint(BudgetJarSummaryDto? summary) {
    if (summary == null) return AppStrings.jarShareHint;
    final left = _remainingShare(summary);
    if (left <= 0) return AppStrings.jarShareOver;
    return '${AppStrings.jarShareHint} Còn chia được $left%.';
  }
}

/// Số tiền tương ứng với tỷ lệ đang gõ — đọc ngay, không cần bấm Lưu.
class _PreviewAmount extends StatelessWidget {
  const _PreviewAmount({required this.budgetAmount, required this.shareText});

  final int budgetAmount;
  final String shareText;

  @override
  Widget build(BuildContext context) {
    final share = int.tryParse(shareText.trim());
    if (share == null || share < 1 || share > 100) {
      return const SizedBox.shrink();
    }
    final amount = (budgetAmount * share) ~/ 100;
    return Row(
      children: [
        const Icon(
          LucideIcons.wallet,
          size: 13,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '≈ ${formatMoney(amount)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          // Vùng chạm tối thiểu 48dp theo quy ước UI của dự án.
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  LucideIcons.check,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
