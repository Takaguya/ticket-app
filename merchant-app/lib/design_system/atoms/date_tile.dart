import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';

enum DateTileStyle {
  /// Black tile with a yellow caption, for today's event.
  highlight,

  /// Grey tile with a red caption, for upcoming events.
  upcoming,

  /// Grey tile with a grey caption, for past events.
  past,
}

/// Small calendar tile: a short caption (month or "TODAY") above a day number.
class DateTile extends StatelessWidget {
  const DateTile({
    super.key,
    required this.caption,
    required this.day,
    this.style = DateTileStyle.upcoming,
  });

  final String caption;
  final String day;
  final DateTileStyle style;

  @override
  Widget build(BuildContext context) {
    final highlight = style == DateTileStyle.highlight;
    final captionColor = switch (style) {
      DateTileStyle.highlight => AppColors.accent,
      DateTileStyle.upcoming => AppColors.danger,
      DateTileStyle.past => AppColors.textMuted,
    };

    return Container(
      width: highlight ? 52 : 44,
      padding: EdgeInsets.symmetric(vertical: highlight ? 6 : 5),
      decoration: BoxDecoration(
        color: highlight ? AppColors.inkSoft : AppColors.fill,
        borderRadius: BorderRadius.circular(highlight ? 10 : 9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: captionColor,
            ),
          ),
          Text(
            day,
            style: TextStyle(
              fontSize: highlight ? 19 : 16,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: highlight ? AppColors.surface : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
