import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/data/api_finance_repository.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/providers.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Màn quản lý ví: xem số dư từng ví, thêm ví với số dư ban đầu, sửa, xoá.
///
/// Đây là chỗ duy nhất khai được "trong ví đang có bao nhiêu tiền". Số dư
/// hiện tại của một ví = số dư ban đầu + thu − chi, nên nếu không có màn này
/// thì con số ở trang chủ luôn chỉ phản ánh giao dịch, không phản ánh tiền có
/// thật.
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WalletsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.walletsTitle)),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _ErrorBody(
          message: '$error',
          onRetry: () => ref.invalidate(walletsProvider),
        ),
        data: (wallets) {
          final total = wallets.fold<int>(0, (sum, w) => sum + (w.balance ?? 0));
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            children: [
              _TotalCard(total: total, count: wallets.length),
              const SizedBox(height: AppSpace.lg),
              if (wallets.isEmpty)
                const _EmptyWallets()
              else
                ...wallets.map(
                  (wallet) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: _WalletTile(wallet: wallet),
                  ),
                ),
              const SizedBox(height: AppSpace.sm),
              OutlinedButton.icon(
                onPressed: () => _WalletSheet.open(context),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text(AppStrings.walletAdd),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              const Text(
                AppStrings.walletsShareNote,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.count});

  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.walletsTotal,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(total),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.walletsCount(count),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletTile extends ConsumerWidget {
  const _WalletTile({required this.wallet});

  final WalletDto wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.md,
        AppSpace.xs,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              _iconFor(wallet.type),
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Hiện cả số dư ban đầu: khi số dư hiện tại trông lạ, người
                  // dùng cần thấy mốc xuất phát để hiểu vì sao.
                  '${AppStrings.walletTypeLabelOf(wallet.type)} · '
                  '${AppStrings.walletInitialShort(formatMoney(wallet.initialBalance))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(wallet.balance ?? 0),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.walletCurrent,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: AppStrings.walletActions,
            icon: const Icon(
              LucideIcons.ellipsisVertical,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onSelected: (value) {
              if (value == 'edit') _WalletSheet.open(context, wallet: wallet);
              if (value == 'delete') _confirmDelete(context, ref, wallet);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text(AppStrings.walletEdit)),
              PopupMenuItem(value: 'delete', child: Text(AppStrings.walletDelete)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WalletDto wallet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.walletDelete),
        content: Text(AppStrings.walletDeleteConfirm(wallet.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cropCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text(AppStrings.walletDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(financeRepositoryProvider);
    try {
      if (repo is ApiFinanceRepository) {
        await repo.deleteWallet(wallet.id, rev: wallet.rev + 1);
      }
      ref.invalidate(walletsProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        _toast(context, AppStrings.walletDeleted);
      }
    } catch (error) {
      if (context.mounted) {
        _toast(context, '${AppStrings.walletSaveFailed} $error');
      }
    }
  }
}

class _EmptyWallets extends StatelessWidget {
  const _EmptyWallets();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Column(
        children: [
          Icon(
            LucideIcons.walletMinimal,
            size: 42,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            AppStrings.walletEmptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          const Text(
            AppStrings.walletEmptyBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Form thêm/sửa ví. Dùng chung một sheet để hai luồng không lệch nhau.
class _WalletSheet extends ConsumerStatefulWidget {
  const _WalletSheet({this.wallet});

  final WalletDto? wallet;

  static Future<void> open(BuildContext context, {WalletDto? wallet}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _WalletSheet(wallet: wallet),
      ),
    );
  }

  @override
  ConsumerState<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<_WalletSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _type;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final wallet = widget.wallet;
    _nameController = TextEditingController(text: wallet?.name ?? '');
    _balanceController = TextEditingController(
      // Ô nhập hiện số thuần, không có "đ" và dấu chấm hàng nghìn: người dùng
      // sửa số dễ hơn, và parser bỏ được cả hai dạng.
      text: wallet == null || wallet.initialBalance == 0
          ? ''
          : '${wallet.initialBalance}',
    );
    _type = wallet?.type ?? 'cash';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final raw = _balanceController.text.trim();
    // Số dư ban đầu được phép bằng 0 (ví vừa mở, chưa có tiền), khác với
    // form giao dịch nơi 0 là vô nghĩa.
    final balance = raw.isEmpty ? 0 : _parseBalance(raw);
    if (balance == null) {
      setState(() => _error = AppStrings.walletBalanceInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(financeRepositoryProvider);
    try {
      if (repo is! ApiFinanceRepository) {
        throw StateError(AppStrings.walletSaveFailed);
      }
      if (_isEdit) {
        await repo.updateWallet(
          id: widget.wallet!.id,
          rev: widget.wallet!.rev,
          name: _nameController.text.trim(),
          initialBalance: balance,
        );
      } else {
        await repo.createWallet(
          name: _nameController.text.trim(),
          type: _type,
          initialBalance: balance,
        );
      }
      ref.invalidate(walletsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(walletNamesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() {
        _saving = false;
        _error = _friendly(error);
      });
    }
  }

  /// Lỗi PLAN_LIMIT có câu riêng vì đây là giới hạn sản phẩm, không phải lỗi
  /// nhập liệu — người dùng cần biết vì sao không thêm được ví thứ tư.
  String _friendly(Object error) {
    final text = '$error';
    if (text.contains('PLAN_LIMIT') || text.contains('3 ví')) {
      return AppStrings.walletLimitReached;
    }
    return '${AppStrings.walletSaveFailed} $text';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? AppStrings.walletEdit : AppStrings.walletAdd,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: AppStrings.walletNameLabel,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return AppStrings.walletNameRequired;
                if (text.length > 80) return AppStrings.walletNameTooLong;
                return null;
              },
            ),
            const SizedBox(height: AppSpace.md),
            if (!_isEdit) ...[
              const Text(
                AppStrings.walletTypeLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final type in const ['cash', 'ewallet', 'bank', 'credit'])
                    ChoiceChip(
                      label: Text(AppStrings.walletTypeLabelOf(type)),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
            ],
            TextFormField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: AppStrings.walletBalanceLabel,
                helperText: AppStrings.walletBalanceHint,
                helperMaxLines: 2,
                suffixText: 'đ',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.expense,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit ? AppStrings.walletSave : AppStrings.walletAddAction,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpace.md),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Số dư ban đầu cho phép 0, khác `parseAmount` của giao dịch.
int? _parseBalance(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\s.,]'), '');
  if (cleaned.isEmpty) return 0;
  final value = int.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return value;
}

IconData _iconFor(String type) => switch (type) {
      'cash' => LucideIcons.banknote,
      'bank' => LucideIcons.landmark,
      'credit' => LucideIcons.creditCard,
      _ => LucideIcons.smartphone,
    };

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
