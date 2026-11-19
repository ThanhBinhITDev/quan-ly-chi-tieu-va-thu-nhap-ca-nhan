import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/core/session/auth_controller.dart';
import 'package:android/providers.dart';
import 'package:android/ui/legal/legal_documents.dart';
import 'package:android/ui/legal/legal_screen.dart';
import 'package:android/ui/profile/avatar_view.dart';
import 'package:android/ui/profile/profile_screen.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Bảng cài đặt: ai đang đăng nhập, vào hồ sơ, xem điều khoản, đăng xuất.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final demo = ref.watch(demoModeProvider);
    final me = ref.watch(meProvider).value;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.settings,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),

            if (session != null)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ProfileScreen.open(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: AppColors.neutralSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      AvatarCircle(size: 46, me: me),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              me?.displayName ?? session.email ?? 'Chưa đăng nhập',
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              me?.username == null
                                  ? (session.email ?? '')
                                  : '@${me!.username}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.neutralSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: const [
                    Icon(
                      LucideIcons.userRound,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: AppSpace.md),
                    Expanded(child: Text('Chưa đăng nhập')),
                  ],
                ),
              ),

            const SizedBox(height: AppSpace.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.scale),
              title: const Text(AppStrings.termsOfUse),
              subtitle: Text('Phiên bản ${LegalDocs.version}'),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                LegalScreen.open(context, tab: LegalTab.terms);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.shieldCheck),
              title: const Text(AppStrings.privacyPolicy),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                LegalScreen.open(context, tab: LegalTab.privacy);
              },
            ),

            if (demo) ...[
              const SizedBox(height: AppSpace.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  ref.read(demoModeProvider.notifier).setDemo(false);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.logIn, size: 18),
                label: const Text('Thoát chế độ xem mẫu'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],

            const SizedBox(height: AppSpace.md),
            if (session != null && !demo)
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
                  side: const BorderSide(color: AppColors.divider),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
