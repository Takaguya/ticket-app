import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

enum AppButtonVariant { primary, outline, tonal, text }

enum AppButtonShape {
  /// Fully rounded, used on the sign-in screens and for main actions.
  pill,

  /// 14px corners.
  rounded,
}

/// The app's button.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.shape = AppButtonShape.pill,
    this.active = true,
    this.loading = false,
    this.foregroundColor,
    this.icon,
    this.height = AppSizes.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonShape shape;

  /// When false the button looks muted but still reports taps, so the screen
  /// can tell the person what is missing instead of ignoring them.
  final bool active;

  /// Shows a spinner and ignores taps.
  final bool loading;

  /// Overrides the label colour, e.g. red for a destructive text button.
  final Color? foregroundColor;

  /// Optional icon before the label.
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      shape == AppButtonShape.pill ? AppRadii.pill : AppRadii.control,
    );
    final (background, defaultForeground, side) = switch (variant) {
      AppButtonVariant.primary when active => (AppColors.primary, AppColors.surface, BorderSide.none),
      AppButtonVariant.primary => (AppColors.disabled, AppColors.onDisabled, BorderSide.none),
      AppButtonVariant.outline => (
        AppColors.surface,
        AppColors.primary,
        const BorderSide(color: AppColors.primary, width: AppSizes.borderWidth),
      ),
      AppButtonVariant.tonal => (AppColors.primarySoft, AppColors.primary, BorderSide.none),
      AppButtonVariant.text => (Colors.transparent, AppColors.primary, BorderSide.none),
    };
    final foreground = foregroundColor ?? defaultForeground;
    // An outline button's border follows its label colour.
    final border = variant == AppButtonVariant.outline ? side.copyWith(color: foreground) : side;

    return Semantics(
      button: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(borderRadius: radius, side: border),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: radius,
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: loading
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 19, color: foreground),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.button.copyWith(color: foreground),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
