import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Rounded option that is either selected or not.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.chip);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: AppSizes.borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              // widthFactor keeps the chip as wide as its label.
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.primary : AppColors.textBody,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
