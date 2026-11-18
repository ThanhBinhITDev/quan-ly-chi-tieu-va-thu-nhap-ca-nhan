import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/ui/budget/budget_tab.dart';
import 'package:android/ui/home/home_tab.dart';
import 'package:android/ui/stats/stats_tab.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/transactions/transactions_tab.dart';

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
    BudgetTab(),
    StatsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
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
            icon: Icon(LucideIcons.wallet),
            selectedIcon: Icon(LucideIcons.wallet),
            label: AppStrings.tabBudget,
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.chartNoAxesColumn),
            selectedIcon: Icon(LucideIcons.chartNoAxesColumn),
            label: AppStrings.tabStats,
          ),
        ],
      ),
    );
  }
}
