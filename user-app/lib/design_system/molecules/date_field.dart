import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// Looks like a text field but shows a chosen date. Tapping it calls [onTap],
/// where the page opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.valueText,
    required this.hintText,
    required this.onTap,
  });

  /// The chosen date as text, or null when none is chosen yet.
  final String? valueText;
  final String hintText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.control);
    final hasValue = valueText != null;
    return Semantics(
      button: true,
      label: hasValue ? null : hintText,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: hasValue ? AppColors.primary : AppColors.border,
            width: AppSizes.borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.fieldHeight),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valueText ?? hintText,
                    style: AppTextStyles.input.copyWith(
                      color: hasValue ? AppColors.ink : AppColors.placeholder,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
