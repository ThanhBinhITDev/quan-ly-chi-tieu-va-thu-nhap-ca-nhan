import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';
import 'package:android/providers.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/home/quick_category_strip.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Mở màn ghi chép giao dịch. Trả về true nếu đã lưu thành công.
///
/// [preselect] dùng cho hàng icon danh mục nhanh: mở màn với danh mục đã
/// chọn sẵn để ghi khoản chi chỉ tốn hai lần chạm.
Future<bool?> openRecordTransaction(
  BuildContext context, {
  CategoryItem? preselect,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => RecordTransactionScreen(preselect: preselect),
    ),
  );
}

/// Màn ghi chép giao dịch riêng (không phải bottom sheet):
/// chọn Thu nhập/Chi tiêu, nhập số tiền lớn, chọn danh mục bằng lưới icon,
/// chọn ví, ghi chú.
class RecordTransactionScreen extends ConsumerStatefulWidget {
  const RecordTransactionScreen({super.key, this.preselect});

  /// Danh mục chọn sẵn khi mở từ hàng icon nhanh.
  final CategoryItem? preselect;

  @override
  ConsumerState<RecordTransactionScreen> createState() =>
      _RecordTransactionScreenState();
}

class _RecordTransactionScreenState
    extends ConsumerState<RecordTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  CategoryItem? _category;
  String? _wallet;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _category = widget.preselect;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<CategoryItem> _categoriesOf(List<CategoryItem> all) {
    // Server trả danh mục kèm `type`; lọc theo loại đang chọn để lưới
    // không hiện "Lương" khi đang ghi khoản chi.
    final wanted = _type == TransactionType.income ? 'income' : 'expense';
    final filtered = all.where((c) => c.type == wanted).toList();
    return filtered.isEmpty ? all : filtered;
  }

  Future<void> _save() async {
    final amount = parseAmount(_amountController.text);
    if (amount == null) {
      setState(() => _error = AppStrings.recordAmountError);
      return;
    }
    final category = _category;
    if (category == null) {
      setState(() => _error = AppStrings.pickCategory);
      return;
    }
    final wallet = _wallet ?? ref.read(walletNamesProvider).value?.firstOrNull;
    if (wallet == null) {
      setState(() => _error = AppStrings.pickWallet);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(financeRepositoryProvider)
          .addTransaction(
            NewTransaction(
              amount: amount,
              type: _type,
              category: category,
              wallet: wallet,
              note: _noteController.text.trim(),
            ),
          );
      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(budgetProgressProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final allCategories = ref.watch(categoriesProvider).value ?? const [];
    final categories = _categoriesOf(allCategories);
    final wallets = ref.watch(walletNamesProvider).value ?? const [];
    final wallet = _wallet ?? (wallets.isEmpty ? null : wallets.first);
    final isExpense = _type == TransactionType.expense;
    final accent = isExpense ? AppColors.expense : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.recordTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: AppStrings.backLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          _TypePicker(
            type: _type,
            onChanged: (value) => setState(() {
              _type = value;
              // Danh mục đã chọn thuộc loại cũ, bỏ để không lưu sai loại.
              _category = null;
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpace.xl),
          _AmountField(
            controller: _amountController,
            accent: accent,
            onClear: () => setState(() {
              _amountController.clear();
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            AppStrings.recordCategoryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.md),
          if (categories.isEmpty)
            Text(
              AppStrings.recordNoCategory,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            _CategoryGrid(
              categories: categories,
              selected: _category,
              accent: accent,
              onPick: (category) => setState(() {
                _category = category;
                _error = null;
              }),
            ),
          const SizedBox(height: AppSpace.xl),
          Text(
            AppStrings.walletLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.sm),
          if (wallets.isEmpty)
            Text(
              AppStrings.pickWallet,
              style: const TextStyle(color: AppColors.expense, fontSize: 13),
            )
          else
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final name in wallets)
                  ChoiceChip(
                    label: Text(name),
                    selected: wallet == name,
                    onSelected: (_) => setState(() => _wallet = name),
                  ),
              ],
            ),
          const SizedBox(height: AppSpace.xl),
          TextField(
            controller: _noteController,
            maxLength: 120,
            // Mặc định Flutter đếm bằng tiếng Anh ("120 characters
            // remaining"). Bỏ bộ đếm, chỉ nói giới hạn ở nhãn phụ.
            buildCounter: (
              _, {
              required int currentLength,
              required bool isFocused,
              int? maxLength,
            }) =>
                null,
            decoration: const InputDecoration(
              labelText: AppStrings.noteLabel,
              helperText: AppStrings.recordNoteHelper,
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.expense, fontSize: 13),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isExpense
                        ? AppStrings.recordSaveExpense
                        : AppStrings.recordSaveIncome,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Hai nút phân loại lớn Thu nhập / Chi tiêu.
class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.type, required this.onChanged});

  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isExpense = type == TransactionType.expense;
    return Row(
      children: [
        Expanded(
          child: _TypeButton(
            label: AppStrings.recordExpense,
            icon: LucideIcons.arrowUpRight,
            selected: isExpense,
            color: AppColors.expense,
            onTap: () => onChanged(TransactionType.expense),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: _TypeButton(
            label: AppStrings.recordIncome,
            icon: LucideIcons.arrowDownLeft,
            selected: !isExpense,
            color: AppColors.primary,
            onTap: () => onChanged(TransactionType.income),
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? color : AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Số tiền cỡ lớn, có nút X để xoá nhanh.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.accent,
    required this.onClear,
  });

  final TextEditingController controller;
  final Color accent;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // Nút X chỉ hiện khi có chữ: theo dõi controller thay vì rebuild cả form.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.45),
              ),
              suffixText: 'đ',
              suffixStyle: TextStyle(fontSize: 20, color: accent),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      tooltip: AppStrings.recordClearAmount,
                      onPressed: onClear,
                    ),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            AppStrings.recordAmountHint,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lưới danh mục: icon + tên, đổi màu khi được chọn.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.accent,
    required this.onPick,
  });

  final List<CategoryItem> categories;
  final CategoryItem? selected;
  final Color accent;
  final ValueChanged<CategoryItem> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpace.md,
        crossAxisSpacing: AppSpace.md,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = selected?.id == category.id;
        return Semantics(
          button: true,
          selected: isSelected,
          label: category.name,
          child: InkWell(
            onTap: () => onPick(category),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? accent : AppColors.divider,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconForCategory(category.name),
                    size: 21,
                    color: isSelected ? accent : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      category.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? accent : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}

/// Nhãn tiền đã nhập dạng gợi ý dưới ô số tiền (dùng cho screen đọc nhanh).
String amountPreview(String raw) {
  final parsed = parseAmount(raw);
  return parsed == null ? '' : formatMoney(parsed);
}
