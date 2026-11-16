import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// "–  2  +": how many of something. "–" is greyed out at zero.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.itemName,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  /// What is counted, for the buttons' tooltips: "Add VIP", "Remove VIP".
  final String itemName;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(9));
    const size = Size.square(36);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: 'Remove $itemName',
          onPressed: quantity > 0 ? onRemove : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
          style: IconButton.styleFrom(
            fixedSize: size,
            minimumSize: size,
            padding: EdgeInsets.zero,
            shape: shape,
            foregroundColor: AppColors.ink,
            disabledForegroundColor: AppColors.placeholder,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
        IconButton.filled(
          tooltip: 'Add $itemName',
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          style: IconButton.styleFrom(
            fixedSize: size,
            minimumSize: size,
            padding: EdgeInsets.zero,
            shape: shape,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface,
          ),
        ),
      ],
    );
  }
}
