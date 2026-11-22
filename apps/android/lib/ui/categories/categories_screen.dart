import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/home/quick_category_strip.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.categoriesTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(categoriesProvider),
          onSignOut: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(message: AppStrings.emptyTransactions);
          }
          final expense = items.where((c) => c.type == 'expense').toList();
          final income = items.where((c) => c.type == 'income').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            children: [
              if (expense.isNotEmpty) ...[
                const _GroupTitle(title: AppStrings.filterExpense),
                const SizedBox(height: AppSpace.sm),
                _CategoryGroup(items: expense, isExpense: true),
                const SizedBox(height: AppSpace.lg),
              ],
              if (income.isNotEmpty) ...[
                const _GroupTitle(title: AppStrings.filterIncome),
                const SizedBox(height: AppSpace.sm),
                _CategoryGroup(items: income, isExpense: false),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.items, required this.isExpense});

  final List<CategoryItem> items;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final color = isExpense ? AppColors.expense : AppColors.income;
    final bg = isExpense ? AppColors.expenseSoft : AppColors.incomeSoft;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  iconForCategory(items[i].name),
                  size: 18,
                  color: color,
                ),
              ),
              title: Text(
                items[i].name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: 2,
              ),
              visualDensity: VisualDensity.compact,
            ),
            if (i != items.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}
