import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/photo_picker_service.dart';
import 'package:android/ui/common/transaction_photos.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/home/quick_category_strip.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Mở màn ghi chép giao dịch. Trả về true nếu đã lưu thành công.
Future<bool?> openRecordTransaction(
  BuildContext context, {
  CategoryItem? preselect,
  TransactionItem? editing,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => RecordTransactionScreen(
        preselect: preselect,
        editing: editing,
      ),
    ),
  );
}

/// Màn ghi chép/sửa giao dịch.
class RecordTransactionScreen extends ConsumerStatefulWidget {
  const RecordTransactionScreen({super.key, this.preselect, this.editing});

  /// Danh mục chọn sẵn khi mở từ hàng icon nhanh.
  final CategoryItem? preselect;
  final TransactionItem? editing;

  @override
  ConsumerState<RecordTransactionScreen> createState() =>
      _RecordTransactionScreenState();
}

class _RecordTransactionScreenState
    extends ConsumerState<RecordTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _incomeSourceController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  CategoryItem? _category;
  String? _wallet;
  DateTime _occurredAt = DateTime.now();
  String _paymentMethod = 'cash';
  Uint8List? _receiptBytes;
  String? _receiptMime;
  final _photoCaptionController = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.type;
      _category = e.category.id.isEmpty ? null : e.category;
      _wallet = e.wallet.isEmpty ? null : e.wallet;
      _amountController.text = e.amount.toString();
      _noteController.text = e.note;
      _occurredAt = e.occurredAt ?? DateTime.now();
      _paymentMethod = e.paymentMethod ?? 'cash';
      _incomeSourceController.text = e.incomeSource ?? '';
      // Ảnh của giao dịch giờ nằm ở bảng `photo_notes`, không còn là cột
      // `receipt_data` của giao dịch. Form sửa giao dịch không tải ảnh về nữa:
      // ảnh được thêm/sửa/xoá ngay trong chi tiết giao dịch.
    } else {
      _category = widget.preselect;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _incomeSourceController.dispose();
    _photoCaptionController.dispose();
    super.dispose();
  }

  List<CategoryItem> _categoriesOf(List<CategoryItem> all) {
    // Server trả danh mục kèm `type`; lọc theo loại đang chọn để lưới
    // không hiện "Lương" khi đang ghi khoản chi.
    final wanted = _type == TransactionType.income ? 'income' : 'expense';
    final filtered = all.where((c) => c.type == wanted).toList();
    return filtered.isEmpty ? all : filtered;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickWalletSheet(List<String> wallets, String? current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final name in wallets)
              ListTile(
                title: Text(name),
                trailing: name == current ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, name),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _wallet = picked);
  }

  Future<void> _pickPaymentSheet() async {
    const items = [
      ('cash', AppStrings.paymentCash),
      ('bank_transfer', AppStrings.paymentTransfer),
      ('card', AppStrings.paymentCard),
      ('ewallet', AppStrings.paymentEwallet),
      ('other', AppStrings.paymentOther),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in items)
              ListTile(
                title: Text(e.$2),
                trailing: e.$1 == _paymentMethod ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, e.$1),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _paymentMethod = picked);
  }

  /// Chọn ảnh cho khoản đang ghi. Ảnh chỉ được đính sau khi khoản đã có id,
  /// nên ở đây chỉ giữ ảnh trong bộ nhớ chờ lưu.
  Future<void> _pickReceipt() async {
    PickedPhoto? photo;
    try {
      photo = await pickAndCompressPhoto(context);
    } on PhotoTooLargeException {
      if (!mounted) return;
      setState(() => _error = AppStrings.recordReceiptTooLarge);
      return;
    } catch (_) {
      return;
    }
    if (photo == null || !mounted) return;
    setState(() {
      _error = null;
      _receiptBytes = photo!.bytes;
      _receiptMime = photo.mime;
    });
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
      final input = NewTransaction(
        amount: amount,
        type: _type,
        category: category,
        wallet: wallet,
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
        paymentMethod: _paymentMethod,
        incomeSource: _type == TransactionType.income
            ? _incomeSourceController.text.trim()
            : null,
      );
      final repo = ref.read(financeRepositoryProvider);
      final editing = widget.editing;
      final String transactionId;
      if (editing != null) {
        final saved = await repo.updateTransaction(editing.id, input, rev: editing.rev);
        transactionId = saved.id;
      } else {
        final saved = await repo.addTransaction(input);
        transactionId = saved.id;
      }
      // Khoản chi **không bắt buộc** có ảnh: chỉ đính khi người dùng đã chọn.
      // Đính sau khi lưu vì ảnh luôn thuộc về một giao dịch đã tồn tại.
      if (_receiptBytes != null) {
        await repo.addPhotoNote(
          transactionId: transactionId,
          bytes: _receiptBytes!,
          mime: _receiptMime ?? 'image/jpeg',
          caption: _photoCaptionController.text.trim().isEmpty
              ? null
              : _photoCaptionController.text.trim(),
        );
      }
      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(allPhotosProvider);
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
        title: Text(_isEditing ? AppStrings.txEditTitle : AppStrings.recordTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: AppStrings.backLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.lg,
        ),
        // Lỗi nằm ngay trên nút Lưu: người dùng bấm Lưu ở đáy màn, nên thông
        // báo phải ở đó. Đặt cuối ListView thì form dài sẽ đẩy nó ra ngoài
        // vùng nhìn và người dùng tưởng nút không làm gì.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: AppColors.expense, fontSize: 13),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size.fromHeight(52),
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
                      _isEditing
                          ? AppStrings.txSaveChanges
                          : (isExpense
                                ? AppStrings.recordSaveExpense
                                : AppStrings.recordSaveIncome),
                    ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
        children: [
          _TypePicker(
            type: _type,
            onChanged: (value) => setState(() {
              _type = value;
              _category = null;
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpace.lg),
          _AmountField(
            controller: _amountController,
            accent: accent,
            onClear: () => setState(() { _amountController.clear(); _error = null; }),
          ),
          const SizedBox(height: AppSpace.md),
          _QuickMetaRow(
            occurredAt: _occurredAt,
            wallet: wallet,
            paymentMethod: _paymentMethod,
            onPickDate: _pickDateTime,
            onPickWallet: wallets.isEmpty ? null : () => _pickWalletSheet(wallets, wallet),
            onPickPayment: () => _pickPaymentSheet(),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(AppStrings.recordCategoryTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.sm),
          if (categories.isEmpty)
            Text(AppStrings.recordNoCategory, style: Theme.of(context).textTheme.bodyMedium)
          else
            _CategoryGrid(
              categories: categories,
              selected: _category,
              accent: accent,
              onPick: (category) => setState(() { _category = category; _error = null; }),
            ),
          const SizedBox(height: AppSpace.md),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(AppStrings.recordMoreDetails, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(AppStrings.recordMoreDetailsHint, style: Theme.of(context).textTheme.bodySmall),
              children: [
                if (!isExpense) ...[
                  TextField(
                    controller: _incomeSourceController,
                    maxLength: 120,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    decoration: const InputDecoration(
                      labelText: AppStrings.recordIncomeSource,
                      hintText: AppStrings.recordIncomeSourceHint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                TextField(
                  controller: _noteController,
                  maxLength: 120,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: const InputDecoration(
                    labelText: AppStrings.noteLabel,
                    helperText: AppStrings.recordNoteHelper,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                // Ảnh là kỷ niệm, không phải bằng chứng — không bao giờ chặn
                // nút Lưu. Sửa giao dịch đã có id thì quản lý ảnh ngay tại
                // chỗ; tạo mới thì giữ ảnh trong bộ nhớ, đính sau khi lưu.
                if (_isEditing) ...[
                  Text(
                    AppStrings.photoSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  TransactionPhotos(transactionId: widget.editing!.id),
                  const SizedBox(height: AppSpace.sm),
                ] else ...[
                  if (_receiptBytes != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.memory(
                                _receiptBytes!,
                                height: 96,
                                width: 96,
                                fit: BoxFit.cover,
                                // Ảnh đã nén ở isolate, giải mã lại lần nữa
                                // cũng không được để khung hình nhấp nháy.
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) => Container(
                                  height: 96,
                                  width: 96,
                                  color: AppColors.neutralSoft,
                                  child: const Icon(
                                    LucideIcons.imageOff,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpace.xs),
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(() {
                                    _receiptBytes = null;
                                    _receiptMime = null;
                                  }),
                                  child: const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Icon(
                                      LucideIcons.x,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                    TextField(
                      controller: _photoCaptionController,
                      maxLength: 500,
                      maxLines: 2,
                      minLines: 1,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: const InputDecoration(
                        labelText: AppStrings.photoCaptionLabel,
                        hintText: AppStrings.photoCaptionHint,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickReceipt,
                              icon: Icon(
                                _receiptBytes == null
                                    ? LucideIcons.camera
                                    : LucideIcons.refreshCw,
                                size: 18,
                              ),
                              label: Text(
                                _receiptBytes == null
                                    ? AppStrings.recordReceiptAdd
                                    : AppStrings.recordPhotoChange,
                              ),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              AppStrings.recordPhotoHint,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
              ],
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

class _QuickMetaRow extends StatelessWidget {
  const _QuickMetaRow({
    required this.occurredAt,
    required this.wallet,
    required this.paymentMethod,
    required this.onPickDate,
    required this.onPickWallet,
    required this.onPickPayment,
  });

  final DateTime occurredAt;
  final String? wallet;
  final String paymentMethod;
  final VoidCallback onPickDate;
  final VoidCallback? onPickWallet;
  final VoidCallback onPickPayment;

  @override
  Widget build(BuildContext context) {
    final date =
        '${occurredAt.day.toString().padLeft(2, '0')}/${occurredAt.month.toString().padLeft(2, '0')}/${occurredAt.year} '
        '${occurredAt.hour.toString().padLeft(2, '0')}:${occurredAt.minute.toString().padLeft(2, '0')}';
    final paymentLabel = AppStrings.paymentMethodLabel(paymentMethod);
    final walletLabel = wallet ?? AppStrings.pickWallet;
    return Column(
      children: [
        _MetaTile(
          icon: LucideIcons.calendarClock,
          label: 'Thời gian',
          value: date,
          onTap: onPickDate,
        ),
        const SizedBox(height: AppSpace.sm),
        _MetaTile(
          icon: LucideIcons.wallet,
          label: AppStrings.recordWalletTileLabel,
          value: walletLabel,
          onTap: onPickWallet,
        ),
        const SizedBox(height: AppSpace.sm),
        _MetaTile(
          icon: LucideIcons.creditCard,
          label: AppStrings.recordPaymentMethodTile,
          value: paymentLabel,
          onTap: onPickPayment,
        ),
      ],
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpace.sm),
            // Nhãn "Phương thức thanh toán" dài hơn 302px của màn 360dp khi
            // cộng thêm icon và giá trị, nên cả hai vế phải co được.
            Flexible(
              flex: 4,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Flexible(
              flex: 5,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
