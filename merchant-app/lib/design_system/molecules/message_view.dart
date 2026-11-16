import 'package:flutter/material.dart';

import '../atoms/app_button.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// Centred message for empty, loading and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.titleColor = AppColors.ink,
    this.messageColor = AppColors.textMuted,
  });

  /// A spinner with nothing else.
  const MessageView.loading({super.key})
    : title = '',
      message = null,
      icon = null,
      actionLabel = null,
      onAction = null,
      titleColor = AppColors.ink,
      messageColor = AppColors.textMuted;

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color titleColor;
  final Color messageColor;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(color: titleColor),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 14, color: messageColor),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: actionLabel!,
                variant: AppButtonVariant.tonal,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
