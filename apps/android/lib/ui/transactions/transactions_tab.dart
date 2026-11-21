import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/filter_chip.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/common/segmented_toggle.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';
import 'package:android/ui/transactions/calendar_tab.dart';
import 'package:android/ui/transactions/photo_journal_screen.dart';

class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  TransactionType? _filter;

  /// 0 = danh sách, 1 = lịch, 2 = sổ ảnh. Ba chế độ chứ không thêm tab thứ
  /// năm: `NavigationBar` M3 phải đúng bốn tab.
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        // Đổi tiêu đề theo chế độ: đang xem lịch mà vẫn đề "Giao dịch" thì
        // người dùng không biết màn này là sổ ảnh hay danh sách.
        title: Text(switch (_mode) {
          1 => AppStrings.calendarTitle,
          2 => AppStrings.photoAllTitle,
          _ => AppStrings.tabTransactions,
        }),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.md),
            child: SegmentedToggle(
              value: _mode,
              segments: const [
                AppStrings.viewList,
                AppStrings.viewCalendar,
                AppStrings.viewPhotos,
              ],
              onChanged: (value) => setState(() => _mode = value),
            ),
          ),
        ],
      ),
      // Lịch tự quản lý trạng thái tải của nó và không dùng bộ lọc chi/thu,
      // nên tách hẳn nhánh thay vì nhét điều kiện vào giữa `when`.
      body: _mode == 1
          ? const CalendarView()
          : _mode == 2
          ? const PhotoJournalScreen()
          : async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(transactionsProvider),
          onSignOut: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(message: AppStrings.emptyTransactions);
          }
          final visible = _filter == null
              ? items
              : items.where((item) => item.type == _filter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.xl,
            ),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterChip(
                      label: AppStrings.filterAll,
                      selected: _filter == null,
                      onSelected: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    AppFilterChip(
                      label: AppStrings.filterExpense,
                      selected: _filter == TransactionType.expense,
                      onSelected: () =>
                          setState(() => _filter = TransactionType.expense),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    AppFilterChip(
                      label: AppStrings.filterIncome,
                      selected: _filter == TransactionType.income,
                      onSelected: () =>
                          setState(() => _filter = TransactionType.income),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              if (visible.isEmpty)
                EmptyView(message: AppStrings.emptyTransactions)
              else
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                  child: Column(
                    children: visible
                        .map(
                          (item) => TransactionTile(
                            key: ValueKey(item.id),
                            item: item,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
