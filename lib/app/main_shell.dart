import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

import '../features/home/home_screen.dart';
import '../features/plans/plans_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/savings/savings_screen.dart';
import 'app_tab.dart';

/// Signed-in frame: five tabs kept alive in an [IndexedStack] so switching
/// tabs keeps scroll position and does not refetch.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _tab = AppTab.home;

  void _open(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from any tab returns to Home before leaving the app.
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(AppTab.home);
      },
      child: Scaffold(
        body: Stack(children: [
          IndexedStack(
            index: _tab.index,
            children: [
              HomeScreen(onOpenTab: _open),
              const SavingsScreen(),
              const PlansScreen(),
              const RewardsScreen(),
              const ProfileScreen(),
            ],
          ),
          // Edge-to-edge: content scrolls under a canvas-coloured status bar
          // backdrop instead of colliding with the system icons.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: const ColoredBox(color: AppColors.canvas),
          ),
        ]),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color!))),
          child: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (i) => _open(AppTab.values[i]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final tab in AppTab.values)
                NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
            ],
          ),
        ),
      ),
    );
  }
}
