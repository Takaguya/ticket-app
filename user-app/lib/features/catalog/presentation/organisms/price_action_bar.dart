import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// Pinned to the bottom of a detail page: the price on the left and the main
/// action ("Select tickets", "Select seats") on the right.
class PriceActionBar extends StatelessWidget {
  const PriceActionBar({
    super.key,
    required this.caption,
    required this.price,
    required this.actionLabel,
    required this.onAction,
    this.actionActive = true,
  });

  /// Above the price, e.g. "From".
  final String caption;
  final String price;
  final String actionLabel;
  final VoidCallback onAction;

  /// When false the button looks muted, e.g. until a showtime is chosen.
  final bool actionActive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caption, style: AppTextStyles.bodySmall.copyWith(fontSize: 12)),
                    Text(price, style: AppTextStyles.title),
                  ],
                ),
              ),
              SizedBox(
                width: 170,
                child: AppButton(label: actionLabel, active: actionActive, onPressed: onAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
