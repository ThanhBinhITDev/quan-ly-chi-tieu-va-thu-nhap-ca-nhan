import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/ui/account/account_tab.dart';
import 'package:android/ui/home/home_tab.dart';
import 'package:android/ui/stats/stats_tab.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/transactions/record_transaction_screen.dart';
import 'package:android/ui/transactions/transactions_tab.dart';
import 'package:android/ui/theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomeTab(),
    TransactionsTab(),
    StatsTab(),
    AccountTab(),
  ];

  int _pageIndexForDestination(int destinationIndex) {
    if (destinationIndex <= 1) return destinationIndex;
    return destinationIndex - 1;
  }

  int _destinationIndexForPage(int pageIndex) {
    if (pageIndex <= 1) return pageIndex;
    return pageIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Chỉ mờ dần + nhích lên 8px: đủ để biết đã đổi tab, không gây
        // cảm giác "nhảy" khi bấm qua lại liên tục.
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        // Key theo tab để AnimatedSwitcher biết nội dung đã đổi. IndexedStack
        // vẫn giữ trạng thái cuộn của từng tab.
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: IndexedStack(index: _selectedIndex, children: _pages),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destinationIndexForPage(_selectedIndex),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == 2) {
            openRecordTransaction(context);
            return;
          }
          setState(() => _selectedIndex = _pageIndexForDestination(index));
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.house),
            selectedIcon: Icon(LucideIcons.house),
            label: AppStrings.tabHome,
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.receiptText),
            selectedIcon: Icon(LucideIcons.receiptText),
            label: AppStrings.tabTransactions,
          ),
          NavigationDestination(
            icon: _AddNavIcon(selected: false),
            selectedIcon: _AddNavIcon(selected: true),
            label: AppStrings.tabAdd,
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.chartNoAxesColumn),
            selectedIcon: Icon(LucideIcons.chartNoAxesColumn),
            label: AppStrings.tabStats,
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.circleUserRound),
            selectedIcon: Icon(LucideIcons.circleUserRound),
            label: AppStrings.tabAccount,
          ),
        ],
      ),
    );
  }
}

class _AddNavIcon extends StatelessWidget {
  const _AddNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 36,
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryDark : AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x332D7C3D),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x262D7C3D),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: const Icon(
        LucideIcons.plus,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
