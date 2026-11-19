import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tabBudget),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(budgetsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            // Không còn chỗ "chuyển sang dữ liệu mẫu": ngân sách trống là
            // trạng thái thật, và tạo ngân sách mới là việc người dùng làm
            // ở màn ngân sách chứ không phải bấm nút đổi kịch bản.
            return const EmptyView(message: AppStrings.emptyBudget);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
            itemBuilder: (context, index) {
              return BudgetTile(key: ValueKey(items[index].id), budget: items[index]);
            },
          );
        },
      ),
    );
  }
}
