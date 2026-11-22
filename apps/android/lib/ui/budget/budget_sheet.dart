import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/core/error/app_exception.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/core/utils/uuid.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';
import 'package:android/providers.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Mở sheet sửa hạn mức cho một ngân sách đã có, hoặc tạo ngân sách mới.
///
/// Chỉ một ngân sách "đang áp dụng" cho mỗi (danh mục, kỳ): đã có thì phải
/// PATCH. Vì vậy sheet nhận [existing]; khi `null` là tạo mới và người dùng
/// được chọn phạm vi (tổng hoặc một danh mục).
Future<bool?> showBudgetSheet(
  BuildContext context, {
  BudgetDto? existing,
  List<CategoryItem> categories = const [],
  int? prefillCategoryIndex,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BudgetSheet(
      existing: existing,
      categories: categories,
      prefillCategoryIndex: prefillCategoryIndex,
    ),
  );
}

class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({
    super.key,
    this.existing,
    this.categories = const [],
    this.prefillCategoryIndex,
  });

  final BudgetDto? existing;
  final List<CategoryItem> categories;

  /// Vị trí danh mục chọn sẵn trong [categories]; `null` = ngân sách tổng.
  final int? prefillCategoryIndex;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  late final TextEditingController _amountController;
  String? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null ? '' : '${existing.amount}',
    );
    _categoryId = existing?.categoryId;
    final index = widget.prefillCategoryIndex;
    if (existing == null && index != null && index < widget.categories.length) {
      _categoryId = widget.categories[index].id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amountController.text);
    if (amount == null) {
      setState(() => _error = AppStrings.budgetAmountError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ref.read(financeApiProvider);
    try {
      final existing = widget.existing;
      if (existing != null) {
        await api.updateBudget(existing.id, {
          'amount': amount,
          'rev': existing.rev + 1,
        });
      } else {
        await api.createBudget({
          'id': generateUuidV4(),
          'category_id': _categoryId,
          'amount': amount,
          'period': 'month',
          // Kỳ bắt đầu từ đầu tháng hiện tại để ngân sách có hiệu lực ngay,
          // thay vì đợi sang tháng sau.
          'start_date': _monthStart(),
        });
      }
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(activeBudgetsProvider);
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // RULE_VIOLATION ở đây nghĩa là đã có hạn mức cho đúng mục này: nói
        // rõ phải sửa chỗ đang có, không phải thêm mới.
        _error = error.code == ApiErrorCode.ruleViolation
            ? AppStrings.budgetExists
            : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppStrings.saveFailed;
      });
    }
  }

  static String _monthStart() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
              isEdit ? AppStrings.budgetEditTotal : AppStrings.budgetNew,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),
            if (!isEdit && widget.categories.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                // Tên danh mục dài ("Tổng tất cả khoản chi") làm hàng bên
                // trong tràn ngang trên máy 360dp nếu không giãn hết bề ngang.
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.budgetScopeLabel,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(AppStrings.budgetScopeTotal),
                  ),
                  for (final category in widget.categories)
                    DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: AppSpace.md),
            ],
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppStrings.budgetAmountLabel,
                suffixText: 'đ',
                helperText: _amountController.text.isEmpty
                    ? null
                    : formatMoney(parseAmount(_amountController.text) ?? 0),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
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
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEdit ? AppStrings.budgetSave : AppStrings.budgetCreate,
                    ),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    AppStrings.budgetJarHint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
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
