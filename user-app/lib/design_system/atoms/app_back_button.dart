import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Back arrow with a 44px tap target.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.onPressed, this.color = AppColors.ink});

  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSizes.tapTarget,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: Icon(Icons.arrow_back_rounded, size: 24, color: color),
      ),
    );
  }
}
