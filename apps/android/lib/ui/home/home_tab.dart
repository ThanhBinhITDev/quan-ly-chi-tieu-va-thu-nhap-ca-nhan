import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/home/quick_category_strip.dart';
import 'package:android/ui/home/savings_challenge_card.dart';
import 'package:android/ui/notifications/notifications_screen.dart';
import 'package:android/ui/profile/avatar_view.dart';
import 'package:android/ui/profile/profile_screen.dart';
import 'package:android/ui/settings/settings_sheet.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';
import 'package:android/ui/wallets/wallets_screen.dart';
import 'package:android/core/session/auth_controller.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    return Scaffold(
      // Bỏ logo và tên app: người dùng đã biết mình đang mở app gì. Chỗ đó
      // dành cho danh tính và thông báo — thứ thay đổi theo từng lần mở.
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(dashboardProvider),
            onSignOut: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          data: (data) {
            final summary = data.summary;
            final budget = data.budgets.firstOrNull;
            final hasAnything = !data.isEmpty || summary.balance != 0;
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardProvider);
                await ref.read(dashboardProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.xl,
                ),
                children: [
                  const _HomeHeader(),
                  const SizedBox(height: AppSpace.lg),
                  if (data.syncStatus == SyncStatus.offline) ...[
                    const OfflineBanner(),
                    const SizedBox(height: AppSpace.md),
                  ],
                  // Số dư luôn hiện, kể cả khi bằng 0: đó là câu trả lời cho
                  // "trong ví mình đang có bao nhiêu", và người dùng cần thấy
                  // số 0 để biết phải thêm ví.
                  HeroBalanceCard(summary: summary),
                  if (!hasAnything) ...[
                    const SizedBox(height: AppSpace.md),
                    const _NoWalletHint(),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  const QuickCategoryStrip(),
                  const SizedBox(height: AppSpace.md),
                  if (hasAnything) PredictionCard(summary: summary),
                  if (hasAnything) ...[
                    const SizedBox(height: AppSpace.xl),
                    _SectionTitle(title: AppStrings.budgetSection),
                    const SizedBox(height: AppSpace.md),
                    if (budget != null)
                      BudgetProgressCard(budget: budget)
                    else
                      const _EmptyRow(
                        icon: LucideIcons.target,
                        text: AppStrings.emptyBudget,
                      ),
                    const SizedBox(height: AppSpace.xl),
                    const SavingsChallengeCard(),
                    const SizedBox(height: AppSpace.xl),
                    _SectionTitle(title: AppStrings.recentTransactions),
                    const SizedBox(height: AppSpace.sm),
                    if (data.recent.isEmpty)
                      const _EmptyRow(
                        icon: LucideIcons.receiptText,
                        text: AppStrings.emptyTransactions,
                      )
                    else
                      SoftCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.xs,
                        ),
                        child: Column(
                          children: data.recent
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cụm nhận diện: avatar + "Xin chào" + tên người dùng bên trái, chuông bên
/// phải đối diện.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    // Ưu tiên tên hiển thị; chưa có hồ sơ thì dùng phần trước @ của email để
    // dòng chào không bao giờ trống.
    final name = (me?.displayName.trim().isNotEmpty ?? false)
        ? me!.displayName.trim()
        : (me?.email?.split('@').first ?? AppStrings.homeGuestName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: AppStrings.profile,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => ProfileScreen.open(context),
            child: AvatarCircle(size: 46, me: me),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.homeGreetingShort,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const _NotificationBell(),
        IconButton(
          tooltip: AppStrings.settings,
          icon: const Icon(LucideIcons.settings2, size: 20),
          onPressed: () => SettingsSheet.show(context),
        ),
      ],
    );
  }
}

/// Chuông kèm chấm đỏ khi có tin chưa đọc.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Badge là thông tin phụ: lỗi tải số chưa đọc không được làm hỏng trang
    // chủ, nên đọc `.value` và bỏ qua lỗi.
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Semantics(
      button: true,
      label: unread > 0
          ? '${AppStrings.notifications}, $unread ${AppStrings.notificationsUnread}'
          : AppStrings.notifications,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: AppStrings.notifications,
            icon: const Icon(LucideIcons.bell, size: 21),
            onPressed: () async {
              await NotificationsScreen.open(context);
              // Đọc xong thì badge phải tắt: màn thông báo đã đánh dấu đã đọc.
              ref.invalidate(unreadCountProvider);
              ref.invalidate(notificationsProvider);
            },
          ),
          if (unread > 0)
            Positioned(
              right: 7,
              top: 7,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('unread-badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 4.5),
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.expense,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Gợi ý khi chưa có đồng nào trong ví: nói thẳng đường đi, vì đây chính là
/// chỗ người dùng hay hỏi "số dư nhập ở đâu".
class _NoWalletHint extends StatelessWidget {
  const _NoWalletHint();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              LucideIcons.walletMinimal,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.noWalletTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.noWalletBody,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          TextButton(
            onPressed: () => WalletsScreen.open(context),
            child: const Text(AppStrings.walletsOpen),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}
