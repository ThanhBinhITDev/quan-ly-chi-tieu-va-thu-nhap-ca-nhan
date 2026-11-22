import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';
import 'package:android/ui/transactions/record_transaction_screen.dart';

/// Hàng icon danh mục nhanh on trang chủ: chạm là mở màn ghi chép với danh
/// mục đó đã chọn sẵn, để ghi một khoản chi chỉ tốn hai lần chạm.
class QuickCategoryStrip extends ConsumerWidget {
  const QuickCategoryStrip({super.key});

  /// Số danh mục hiện trên hàng: quá nhiều thì thành lưới, mất ý "nhanh".
  static const maxItems = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final wanted = categories
        .where((c) => c.type == 'expense')
        .take(maxItems)
        .toList();
    if (wanted.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Text trong Row không tự xuống dòng: chữ 200% làm "Ghi nhanh"
            // rộng hơn cả hàng và tràn 1.4px. Expanded cho nó bề ngang để tự
            // cắt, thay vì đẩy ra ngoài.
            Expanded(
              child: Text(
                AppStrings.quickCategories,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          // spaceBetween cộng thêm khoảng trống giữa các mục, mà mỗi mục đã
          // là Expanded — ở màn hẹp với chữ lớn, tổng đó vượt bề ngang và tràn
          // 1.4px (đủ để vẽ dải vàng đen). Chia đều bằng Expanded là đủ.
          children: [
            for (final category in wanted)
              Expanded(
                child: _QuickCategoryButton(category: category),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickCategoryButton extends StatelessWidget {
  const _QuickCategoryButton({required this.category});

  final CategoryItem category;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${AppStrings.recordExpense} ${category.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => openRecordTransaction(context, preselect: category),
        child: Column(
          // Nút rộng 46dp cố định; ở cột hẹp hơn 46dp (5 mục trên màn 320dp)
          // nó đẩy cột rộng ra và tràn Row. Cho icon co theo bề ngang cột.
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Center(
                  child: Icon(
                    iconForCategory(category.name),
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon theo tên danh mục; tên lạ rơi về icon trung tính.
///
/// Đặt ở một chỗ để hàng nhanh và lưới trong màn ghi chép luôn khớp nhau.
IconData iconForCategory(String name) {
  final key = name.toLowerCase();
  if (key.contains('ăn') || key.contains('uống')) return LucideIcons.utensils;
  if (key.contains('đi lại') || key.contains('xăng')) return LucideIcons.bus;
  if (key.contains('học') || key.contains('sách')) return LucideIcons.bookOpen;
  if (key.contains('giải trí') || key.contains('chơi')) {
    return LucideIcons.gamepad2;
  }
  if (key.contains('mua sắm') || key.contains('quần')) {
    return LucideIcons.shoppingBag;
  }
  if (key.contains('lương') || key.contains('thu')) return LucideIcons.banknote;
  if (key.contains('nhà') || key.contains('trọ')) return LucideIcons.house;
  if (key.contains('sức') || key.contains('y tế')) return LucideIcons.heartPulse;
  return LucideIcons.tag;
}
