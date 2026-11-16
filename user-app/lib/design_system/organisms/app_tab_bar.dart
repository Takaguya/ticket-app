import 'package:flutter/material.dart';

import '../molecules/nav_tab_button.dart';
import '../tokens/app_colors.dart';

/// One destination of an [AppTabBar].
class AppTabItem {
  const AppTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Bottom tab bar: Home, Activity, Message and Profile.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: NavTabButton(
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
