import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// Small rounded label, e.g. the yellow "Owner" tag or a booking status.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.backgroundColor = AppColors.accent,
    this.foregroundColor = AppColors.inkSoft,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: AppTextStyles.badge.copyWith(color: foregroundColor)),
      ),
    );
  }
}
