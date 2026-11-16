import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// Asks before an action, e.g. "Sign out?". Completes with true when the
/// person confirms, false when they cancel or dismiss the dialog.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card + 4)),
      title: Text(title, style: AppTextStyles.title),
      content: Text(message, style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: destructive ? AppColors.danger : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
