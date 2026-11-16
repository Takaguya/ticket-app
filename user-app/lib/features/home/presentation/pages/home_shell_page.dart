import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/organisms/app_tab_bar.dart';
import '../home_tab.dart';

/// Signed-in area: the current tab and the tab bar.
///
/// Each tab is a branch of the router's `StatefulShellRoute`, so it has its
/// own URL and back stack, and keeps its state while another tab is showing.
class HomeShellPage extends StatelessWidget {
  const HomeShellPage({super.key, required this.navigationShell});

  /// The router's shell: the branch navigators and which one is showing.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppTabBar(
        items: [for (final tab in HomeTab.values) AppTabItem(icon: tab.icon, label: tab.label)],
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are on returns to its first page.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
