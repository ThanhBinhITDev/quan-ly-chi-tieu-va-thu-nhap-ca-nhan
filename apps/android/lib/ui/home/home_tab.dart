import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/scenario_menu.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/profile/avatar_view.dart';
import 'package:android/ui/profile/profile_screen.dart';
import 'package:android/ui/settings/settings_sheet.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/app-icon-round.png',
              width: 26,
              height: 26,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: AppSpace.sm),
            Flexible(
              child: Text(
                AppStrings.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: const [ScenarioMenu()],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) {
          if (data.isEmpty) {
            return EmptyView(
              message: AppStrings.emptyHome,
              actionLabel: AppStrings.scenarioReady,
              onAction: () =>
                  ref.read(scenarioProvider.notifier).select(DemoScenario.ready),
            );
          }
          final summary = data.summary;
          final budget = data.budgets.firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            children: [
              if (data.syncStatus == SyncStatus.offline) ...[
                const OfflineBanner(),
                const SizedBox(height: AppSpace.md),
              ],
              _GreetingHeader(),
              const SizedBox(height: AppSpace.lg),
              HeroBalanceCard(summary: summary),
              const SizedBox(height: AppSpace.md),
              PredictionCard(summary: summary),
              const SizedBox(height: AppSpace.xl),
              _SectionTitle(title: AppStrings.budgetSection),
              const SizedBox(height: AppSpace.md),
              if (budget != null) BudgetProgressCard(budget: budget),
              const SizedBox(height: AppSpace.xl),
              _SectionTitle(title: AppStrings.recentTransactions),
              const SizedBox(height: AppSpace.sm),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
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
          );
        },
      ),
    );
  }
}

class _GreetingHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.homeGreeting,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.homeOverview,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        // Ảnh hồ sơ thay cho icon cài đặt: một chạm là vào hồ sơ, và người
        // dùng thấy ngay mình đang đăng nhập bằng tài khoản nào.
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Semantics(
            button: true,
            label: AppStrings.profile,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => ProfileScreen.open(context),
              child: const AvatarCircle(size: 40),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: AppStrings.settings,
          icon: const Icon(LucideIcons.settings2, size: 20),
          onPressed: () => SettingsSheet.show(context),
        ),
      ],
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
