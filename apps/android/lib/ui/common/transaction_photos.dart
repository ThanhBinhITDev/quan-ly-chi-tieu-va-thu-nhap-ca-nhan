import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/photo_picker_service.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Ảnh của một khoản chi/thu, xem và sửa ngay trong chi tiết giao dịch.
///
/// Khoản chi **không bắt buộc** phải có ảnh — đó là toàn bộ điểm của phần
/// này. Không có ảnh thì hiện lời mời thêm, không phải ô trống vô nghĩa.
class TransactionPhotos extends ConsumerWidget {
  const TransactionPhotos({
    super.key,
    required this.transactionId,
    this.editable = true,
  });

  final String transactionId;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionPhotosProvider(transactionId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.photoLoadFailed,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (editable)
            _AddButton(
              transactionId: transactionId,
              onDone: () => ref.invalidate(
                transactionPhotosProvider(transactionId),
              ),
            ),
        ],
      ),
      data: (photos) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text(
                AppStrings.photoNoneYet,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (context, index) => _PhotoCard(
                  note: photos[index],
                  editable: editable,
                  // Sổ ảnh là một danh sách riêng: sửa ghi chú ở đây mà chỉ
                  // làm mới danh sách của giao dịch thì sổ ảnh vẫn hiện chữ
                  // cũ cho tới lần mở app sau.
                  onChanged: () {
                    ref.invalidate(transactionPhotosProvider(transactionId));
                    ref.invalidate(allPhotosProvider);
                  },
                ),
              ),
            ),
          if (editable) ...[
            const SizedBox(height: AppSpace.sm),
            _AddButton(
              transactionId: transactionId,
              onDone: () {
                ref.invalidate(transactionPhotosProvider(transactionId));
                ref.invalidate(allPhotosProvider);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AddButton extends ConsumerStatefulWidget {
  const _AddButton({required this.transactionId, required this.onDone});

  final String transactionId;
  final VoidCallback onDone;

  @override
  ConsumerState<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends ConsumerState<_AddButton> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    PickedPhoto? photo;
    try {
      photo = await pickAndCompressPhoto(context);
    } on PhotoTooLargeException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.recordReceiptTooLarge)),
      );
      return;
    } catch (_) {
      return;
    }
    if (photo == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final note = await ref
          .read(financeRepositoryProvider)
          .addPhotoNote(
            transactionId: widget.transactionId,
            bytes: photo.bytes,
            mime: photo.mime,
          );
      // Ảnh mới có bytes sẵn; nạp luôn vào cache để ô lưới không phải tải lại.
      ref.invalidate(photoBytesProvider(note.id));
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onDone();
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.txPhotoAdded)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _add,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.camera, size: 16),
      label: const Text(AppStrings.photoAdd),
    );
  }
}

/// Một tấm ảnh: ảnh + ghi chú của nó, sửa và xoá được.
class _PhotoCard extends ConsumerWidget {
  const _PhotoCard({
    required this.note,
    required this.editable,
    required this.onChanged,
  });

  final PhotoNote note;
  final bool editable;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(photoBytesProvider(note.id));

    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: editable ? () => _openActions(context, ref) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 110,
                height: 92,
                child: bytes.when(
                  loading: () => Container(color: AppColors.neutralSoft),
                  error: (_, _) => const _Fallback(),
                  data: (raw) => raw == null
                      ? const _Fallback()
                      : Image.memory(
                          raw,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          // Ảnh hỏng thì hiện icon, không vẽ chuỗi ngoại lệ.
                          errorBuilder: (_, _, _) => const _Fallback(),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note.displayCaption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: note.caption?.isNotEmpty == true
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil, color: AppColors.primary),
              title: const Text(AppStrings.photoEditCaption),
              onTap: () {
                Navigator.pop(ctx);
                _editCaption(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.expense),
              title: const Text(AppStrings.photoDelete),
              onTap: () {
                Navigator.pop(ctx);
                _delete(context, ref);
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _editCaption(BuildContext context, WidgetRef ref) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _CaptionEditor(initial: note.caption ?? ''),
    );
    if (text == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(financeRepositoryProvider)
          .updatePhotoNoteCaption(note.id, text, rev: note.rev);
      ref.invalidate(photoBytesProvider(note.id));
      onChanged();
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.photoCaptionSaved)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.photoDeleteConfirm),
        content: const Text(AppStrings.photoDeleteConfirmNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.photoDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(financeRepositoryProvider).deletePhotoNote(note.id);
      onChanged();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

/// Hộp thoại sửa ghi chú ảnh.
///
/// Tự giữ `TextEditingController` và chỉ giải phóng khi chính nó bị gỡ khỏi
/// cây. Bản trước tạo controller trong hàm gọi rồi `dispose()` ngay sau khi
/// `showDialog` trả về — lúc đó hộp thoại vẫn đang chạy hiệu ứng đóng và còn
/// đọc controller, nên Flutter ném "used after being disposed".
class _CaptionEditor extends StatefulWidget {
  const _CaptionEditor({required this.initial});

  final String initial;

  @override
  State<_CaptionEditor> createState() => _CaptionEditorState();
}

class _CaptionEditorState extends State<_CaptionEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.photoEditCaption),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 500,
        maxLines: 3,
        minLines: 1,
        decoration: const InputDecoration(
          hintText: AppStrings.photoCaptionHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text(AppStrings.photoSaveCaption),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutralSoft,
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.imageOff,
        size: 18,
        color: AppColors.textSecondary,
      ),
    );
  }
}
