import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Minus button, a number and a plus button.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;

  /// Always called on tap, so the screen can explain a limit.
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final canDecrement = quantity > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: canDecrement ? 1 : 0.35,
          child: _RoundButton(
            icon: Icons.remove_rounded,
            tooltip: 'Fewer',
            color: AppColors.ink,
            backgroundColor: AppColors.surface,
            borderColor: AppColors.border,
            onTap: canDecrement ? onDecrement : null,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        _RoundButton(
          icon: Icons.add_rounded,
          tooltip: 'More',
          color: AppColors.primary,
          backgroundColor: AppColors.primarySoft,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
    this.borderColor,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: CircleBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!, width: AppSizes.borderWidth),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: AppSizes.tapTarget,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}
