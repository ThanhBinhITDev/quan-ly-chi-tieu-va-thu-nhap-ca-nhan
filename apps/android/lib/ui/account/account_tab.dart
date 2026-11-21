import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/ui/budget/budget_tab.dart';
import 'package:android/ui/categories/categories_screen.dart';
import 'package:android/ui/legal/legal_screen.dart';
import 'package:android/ui/notifications/notifications_screen.dart';
import 'package:android/ui/profile/avatar_view.dart';
import 'package:android/ui/profile/profile_screen.dart';
import 'package:android/ui/settings/settings_sheet.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';
import 'package:android/ui/wallets/wallets_screen.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final me = ref.watch(meProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.accountTitle),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            AppSpace.xxl,
          ),
          children: [
            _ProfileHeader(
              name: me?.displayName ?? session?.email ?? 'Chưa đăng nhập',
              subtitle: me?.username != null
                  ? '@${me!.username}'
                  : (session?.email ?? ''),
              me: me,
              onTap: session == null ? null : () => ProfileScreen.open(context),
            ),
            const SizedBox(height: AppSpace.lg),
            _SectionCard(
              children: [
                _Item(
                  icon: LucideIcons.walletCards,
                  label: AppStrings.walletsTitle,
                  onTap: () => WalletsScreen.open(context),
                ),
                _Item(
                  icon: LucideIcons.tags,
                  label: AppStrings.categoriesTitle,
                  onTap: () => CategoriesScreen.open(context),
                ),
                _Item(
                  icon: LucideIcons.target,
                  label: '${AppStrings.budgetSection} / ${AppStrings.tabBudget}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BudgetTab()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _SectionCard(
              children: [
                _Item(
                  icon: LucideIcons.bell,
                  label: AppStrings.notifications,
                  onTap: () => NotificationsScreen.open(context),
                ),
                _Item(
                  icon: LucideIcons.settings,
                  label: AppStrings.settings,
                  onTap: () => SettingsSheet.show(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _SectionCard(
              children: [
                _Item(
                  icon: LucideIcons.scale,
                  label: AppStrings.termsOfUse,
                  onTap: () => LegalScreen.open(context, tab: LegalTab.terms),
                ),
                _Item(
                  icon: LucideIcons.shieldCheck,
                  label: AppStrings.privacyPolicy,
                  subtitle: AppStrings.legalTabPrivacy,
                  onTap: () => LegalScreen.open(context, tab: LegalTab.privacy),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            if (session != null)
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.me,
    this.onTap,
  });

  final String name;
  final String subtitle;
  final MeDto? me;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            AvatarCircle(size: 56, me: me),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: _withDividers(children)),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(const Divider(height: 1, color: AppColors.divider));
      }
    }
    return out;
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: AppColors.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: 2,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
