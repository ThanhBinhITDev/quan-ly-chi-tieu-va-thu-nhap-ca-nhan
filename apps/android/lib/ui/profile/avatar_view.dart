import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hồ sơ người dùng hiện tại. `null` khi chưa đăng nhập hoặc đang xem demo.
final meProvider = FutureProvider<MeDto?>((ref) async {
  final signedIn = ref.watch(isSignedInProvider);
  if (!signedIn) return null;
  return ref.watch(financeApiProvider).me();
});

/// Bytes ảnh đại diện, `null` nếu chưa đặt.
///
/// Tách khỏi [meProvider] vì ảnh là request riêng (và có thể nặng): đổi tên
/// hiển thị không cần tải lại ảnh, đổi ảnh chỉ cần `ref.invalidate` provider này.
final avatarBytesProvider = FutureProvider<Uint8List?>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null || !me.hasAvatar) return null;
  return ref.watch(financeApiProvider).avatarBytes();
});

/// Ảnh đại diện tròn, tự thay bằng chữ cái đầu khi chưa có ảnh.
class AvatarCircle extends ConsumerWidget {
  const AvatarCircle({
    super.key,
    this.size = 44,
    this.me,
    this.showEditBadge = false,
  });

  final double size;

  /// Truyền vào khi đã có dữ liệu để tránh tải lại; `null` thì tự lấy.
  final MeDto? me;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = me ?? ref.watch(meProvider).value;
    final bytes = profile?.hasAvatar == true
        ? ref.watch(avatarBytesProvider).value
        : null;

    final avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: bytes == null
            ? _Initials(me: profile, size: size)
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _Initials(me: profile, size: size),
              ),
      ),
    );

    if (!showEditBadge) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: Icon(
              Icons.edit_rounded,
              size: size * 0.16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.me, required this.size});

  final MeDto? me;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
        child: Text(
          me?.initials ?? '?',
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
