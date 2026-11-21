import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/core/error/app_exception.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/ui/legal/legal_screen.dart';
import 'package:android/ui/legal/legal_documents.dart';
import 'package:android/ui/profile/avatar_crop_screen.dart';
import 'package:android/ui/profile/avatar_view.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Màn hình hồ sơ: ảnh đại diện, tên hiển thị, tên người dùng, email.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _username = TextEditingController();

  MeDto? _loaded;
  bool _saving = false;
  bool _uploading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    super.dispose();
  }

  /// Đổ dữ liệu vào form đúng một lần cho mỗi bản hồ sơ, để không ghi đè
  /// những gì người dùng đang gõ khi provider làm mới.
  void _syncForm(MeDto me) {
    if (_loaded?.id == me.id && _loaded == me) return;
    _loaded = me;
    _displayName.text = me.displayName;
    _username.text = me.username ?? '';
  }

  bool get _dirty {
    final me = _loaded;
    if (me == null) return false;
    final name = _displayName.text.trim();
    final user = _username.text.trim();
    return name != me.displayName || user != (me.username ?? '');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final api = ref.read(financeApiProvider);
      final updated = await api.updateMe(
        displayName: _displayName.text.trim(),
        username: _username.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loaded = updated;
        _notice = AppStrings.profileSaved;
      });
      ref.invalidate(meProvider);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    setState(() => _error = null);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Ảnh gốc từ camera có thể 12 MP; giải mã ảnh đó vừa tốn RAM vừa
        // không cần thiết vì đích cuối cùng chỉ 512×512.
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        setState(() => _error = AppStrings.avatarTooLarge);
        return;
      }
      if (!mounted) return;
      final cropped = await AvatarCropScreen.open(context, bytes: bytes);
      if (cropped == null || !mounted) return;
      await _uploadAvatar(cropped);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Không mở được thư viện ảnh: $error');
    }
  }

  Future<void> _uploadAvatar(Uint8List jpeg) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final me = await ref.read(financeApiProvider).uploadAvatar(
            base64Data: base64Encode(jpeg),
          );
      if (!mounted) return;
      setState(() {
        _loaded = me;
        _notice = null;
      });
      ref.invalidate(meProvider);
      ref.invalidate(avatarBytesProvider);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploading = true);
    try {
      final me = await ref.read(financeApiProvider).deleteAvatar();
      if (!mounted) return;
      setState(() => _loaded = me);
      ref.invalidate(meProvider);
      ref.invalidate(avatarBytesProvider);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text(AppStrings.pickFromGallery),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text(AppStrings.pickFromCamera),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (_loaded?.hasAvatar == true)
              ListTile(
                leading: const Icon(
                  LucideIcons.trash2,
                  color: AppColors.expense,
                ),
                title: const Text(
                  'Xoá ảnh đại diện',
                  style: TextStyle(color: AppColors.expense),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removeAvatar();
                },
              ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProvider);
    final me = _loaded ?? meAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profile)),
      body: meAsync.when(
        loading: () => me == null
            ? const Center(child: CircularProgressIndicator())
            : _body(context, me),
        error: (error, _) => _ErrorState(
          message: error is AppException ? error.message : '$error',
          onRetry: () => ref.invalidate(meProvider),
        ),
        data: (data) {
          if (data == null) {
            return const _ErrorState(
              message: 'Bạn cần đăng nhập để xem hồ sơ.',
            );
          }
          _syncForm(data);
          return _body(context, data);
        },
      ),
    );
  }

  Widget _body(BuildContext context, MeDto me) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.xxl,
      ),
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _uploading ? null : _showAvatarOptions,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AvatarCircle(me: me, size: 104, showEditBadge: true),
                    if (_uploading)
                      const SizedBox(
                        width: 104,
                        height: 104,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              TextButton(
                onPressed: _uploading ? null : _showAvatarOptions,
                child: const Text(AppStrings.avatarChange),
              ),
              Text(
                AppStrings.avatarHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),

        if (_error != null) ...[
          _Banner(
            message: _error!,
            color: AppColors.expense,
            background: AppColors.expenseSoft,
            icon: LucideIcons.circleAlert,
          ),
          const SizedBox(height: AppSpace.lg),
        ],
        if (_notice != null) ...[
          _Banner(
            message: _notice!,
            color: AppColors.income,
            background: AppColors.incomeSoft,
            icon: LucideIcons.checkCircle2,
          ),
          const SizedBox(height: AppSpace.lg),
        ],

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _displayName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: AppStrings.displayNameLabel,
                  prefixIcon: Icon(LucideIcons.user),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return AppStrings.nameRequired;
                  if (text.length > 60) return 'Tên tối đa 60 ký tự.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: AppStrings.usernameLabel,
                  helperText: AppStrings.usernameHint,
                  prefixIcon: Icon(LucideIcons.atSign),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final ok = RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(text);
                  return ok ? null : AppStrings.usernameHint;
                },
              ),
              const SizedBox(height: AppSpace.xl),
              FilledButton(
                onPressed: (_saving || !_dirty) ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(AppStrings.saveProfile),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpace.xl),
        const Divider(),
        const SizedBox(height: AppSpace.md),

        _InfoRow(
          icon: LucideIcons.mail,
          label: AppStrings.emailLabel,
          value: me.email ?? '—',
        ),
        // Nói rõ vì sao email không sửa được ở đây: đổi email là đổi danh
        // tính đăng nhập, phải qua Supabase Auth + xác nhận qua hộp thư. Hứa
        // một nút bấm rồi báo lỗi còn tệ hơn là không có nút.
        const Padding(
          padding: EdgeInsets.only(left: 36, bottom: AppSpace.sm),
          child: Text(
            'Email dùng để đăng nhập. Muốn đổi, liên hệ hỗ trợ để xác minh '
            'danh tính.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (me.createdAt != null)
          _InfoRow(
            icon: LucideIcons.calendarDays,
            label: AppStrings.memberSince,
            value: _formatDate(me.createdAt!),
          ),

        const SizedBox(height: AppSpace.md),
        const Divider(),
        const SizedBox(height: AppSpace.md),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.scale),
          title: const Text(AppStrings.termsOfUse),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => LegalScreen.open(context, tab: LegalTab.terms),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.shieldCheck),
          title: const Text(AppStrings.privacyPolicy),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => LegalScreen.open(context, tab: LegalTab.privacy),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          child: Text(
            'Phiên bản ${LegalDocs.version} · cập nhật ${LegalDocs.updatedAt}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: AppSpace.xl),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(LucideIcons.logOut, size: 18),
          label: const Text(AppStrings.signOutAction),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.expense,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.circleAlert,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpace.md),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
