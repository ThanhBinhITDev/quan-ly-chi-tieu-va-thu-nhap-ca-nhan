import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';
import 'package:android/providers.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Mở form thêm giao dịch. Trả về true nếu đã ghi thành công.
Future<bool?> showAddTransactionSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const AddTransactionSheet(),
  );
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  CategoryItem? _category;
  String _wallet = AppStrings.walletCash;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final category = _category;
    if (category == null) {
      setState(() => _saveError = AppStrings.pickCategory);
      return;
    }
    final amount = parseAmount(_amountController.text);
    if (amount == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref.read(financeRepositoryProvider).addTransaction(
            NewTransaction(
              amount: amount,
              type: _type,
              category: category,
              wallet: _wallet,
              note: _noteController.text.trim(),
            ),
          );
      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = AppStrings.saveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.read(financeRepositoryProvider).categories;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.addTransaction,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.lg),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text(AppStrings.filterExpense),
                    icon: Icon(LucideIcons.trendingDown, size: 16),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text(AppStrings.filterIncome),
                    icon: Icon(LucideIcons.trendingUp, size: 16),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
              ),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: AppStrings.amountLabel,
                  suffixText: 'đ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    validateTransaction(rawAmount: value ?? '').amountError,
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<CategoryItem>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: AppStrings.categoryLabel,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c, child: Text(c.name)),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                initialValue: _wallet,
                decoration: const InputDecoration(
                  labelText: AppStrings.walletLabel,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AppStrings.walletCash,
                    child: Text(AppStrings.walletCash),
                  ),
                  DropdownMenuItem(
                    value: AppStrings.walletBank,
                    child: Text(AppStrings.walletBank),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _wallet = value ?? _wallet),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _noteController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: AppStrings.noteLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  _saveError!,
                  style: const TextStyle(color: AppColors.expense),
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
                    : const Text(AppStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
