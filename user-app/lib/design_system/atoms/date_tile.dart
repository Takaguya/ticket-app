import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';

enum DateTileStyle {
  /// Black tile with a yellow month, for a booked ticket ("Coming up").
  dark,

  /// White tile with a red month, on a poster.
  light,
}

/// Small calendar tile: the month above the day number, e.g. "NOV 22".
class DateTile extends StatelessWidget {
  const DateTile({
    super.key,
    required this.month,
    required this.day,
    this.style = DateTileStyle.light,
  });

  final String month;
  final String day;
  final DateTileStyle style;

  @override
  Widget build(BuildContext context) {
    final dark = style == DateTileStyle.dark;
    return Container(
      width: dark ? 52 : 40,
      padding: EdgeInsets.symmetric(vertical: dark ? 7 : 4),
      decoration: BoxDecoration(
        color: dark ? AppColors.inkSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(dark ? 10 : 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            month.toUpperCase(),
            style: TextStyle(
              fontSize: dark ? 10.5 : 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: dark ? AppColors.accent : AppColors.event,
            ),
          ),
          Text(
            day,
            style: TextStyle(
              fontSize: dark ? 19 : 15,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: dark ? AppColors.surface : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
