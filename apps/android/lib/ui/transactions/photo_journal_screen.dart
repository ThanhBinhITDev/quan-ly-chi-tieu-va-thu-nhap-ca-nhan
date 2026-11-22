import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Sổ ảnh: lưới ảnh của mọi khoản chi/thu, mới nhất trước.
///
/// Mỗi ô là một tấm ảnh kèm ghi chú của chính nó — đọc như một cuốn nhật ký
/// bằng ảnh. Ảnh luôn thuộc một giao dịch, nên bấm vào mở được khoản chi đó.
class PhotoJournalScreen extends ConsumerWidget {
  const PhotoJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allPhotosProvider);

    return async.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(allPhotosProvider),
      ),
      data: (photos) {
        if (photos.isEmpty) {
          return const EmptyView(message: AppStrings.photoAllEmpty);
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm,
            AppSpace.md,
            AppSpace.xl,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpace.md,
            crossAxisSpacing: AppSpace.md,
            childAspectRatio: 0.78,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) => _PhotoTile(note: photos[index]),
        );
      },
    );
  }
}
/// Một ô ảnh: ảnh ở trên, ghi chú ở dưới.
///
/// Ảnh tải riêng từng cái vì danh sách cố tình không mang bytes — 20 ảnh ×
/// 400KB trong một lần gọi là quá nặng cho cả mạng lẫn bộ nhớ máy.
class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.note});

  final PhotoNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(photoBytesProvider(note.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _openTransaction(context, ref),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: bytes.when(
                loading: () => Container(color: AppColors.neutralSoft),
                error: (_, _) => const _PhotoFallback(),
                data: (raw) => raw == null
                    ? const _PhotoFallback()
                    : Image.memory(
                        raw,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        gaplessPlayback: true,
                        // Ảnh hỏng thì hiện icon, đừng để Flutter vẽ chuỗi
                        // ngoại lệ lên lưới.
                        errorBuilder: (_, _, _) => const _PhotoFallback(),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          note.displayCaption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: note.caption?.isNotEmpty == true
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
        Text(
          formatDayLabel(note.takenAt),
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Mở khoản chi/thu chứa ảnh này. Sổ ảnh chỉ giữ id giao dịch, nên phải
  /// hỏi server một lần — đổi lại danh sách ảnh nhẹ, không kéo theo cả
  /// giao dịch chỉ để hiện một tấm ảnh.
  Future<void> _openTransaction(BuildContext context, WidgetRef ref) async {
    try {
      final item = await ref
          .read(financeRepositoryProvider)
          .fetchTransaction(note.transactionId);
      if (!context.mounted) return;
      showTransactionDetail(context, item);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutralSoft,
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.imageOff,
        size: 20,
        color: AppColors.textSecondary,
      ),
    );
  }
}
