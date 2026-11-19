import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/filter_chip.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/transactions/add_transaction_sheet.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  TransactionType? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tabTransactions),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(transactionsProvider),
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
              AppSpace.xxl,
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-transactions',
        onPressed: () => showAddTransactionSheet(context),
        tooltip: AppStrings.addTransaction,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(AppStrings.addTransaction),
      ),
    );
  }
}
