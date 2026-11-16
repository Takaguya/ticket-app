import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/organisms/app_tab_bar.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../dashboard/presentation/organisms/new_booking_toaster.dart';
import '../home_tab.dart';
import '../organisms/session_refresher.dart';

/// Signed-in area: the current tab and the tab bar.
///
/// Each tab is a branch of the router's `StatefulShellRoute`, so it has its
/// own URL and back stack, and keeps its state while another tab is showing.
/// Bookings made in the Pin user app are announced with a toast on any tab.
/// Expects an [AuthBloc] and a `BusinessBloc` above it.
class HomeShellPage extends StatelessWidget {
  const HomeShellPage({super.key, required this.navigationShell});

  /// The router's shell: the branch navigators and which one is showing.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final role = context.select((AuthBloc bloc) => bloc.state.user?.role);
    // Signing out: the router is about to leave this page.
    if (role == null) return const Scaffold(backgroundColor: AppColors.background);

    final tabs = HomeTab.forRole(role);
    final current = HomeTab.values[navigationShell.currentIndex];

    return SessionRefresher(
      child: NewBookingToaster(
        child: Scaffold(
          backgroundColor: current == HomeTab.scan ? AppColors.dark : AppColors.background,
          body: navigationShell,
          bottomNavigationBar: AppTabBar(
            items: [for (final tab in tabs) AppTabItem(icon: tab.icon, label: tab.label)],
            currentIndex: tabs.contains(current) ? tabs.indexOf(current) : 0,
            onSelected: (index) {
              final tab = tabs[index];
              navigationShell.goBranch(
                tab.index,
                // Tapping the tab you are on returns to its first page.
                initialLocation: tab == current,
              );
            },
          ),
        ),
      ),
    );
  }
}
