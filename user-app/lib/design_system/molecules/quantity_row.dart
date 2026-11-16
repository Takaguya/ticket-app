import 'package:flutter/material.dart';

import '../tokens/app_text_styles.dart';
import 'quantity_stepper.dart';

/// Something to buy several of: a picture on the left, its name, what it
/// includes and its price, and a [QuantityStepper] on the right.
class QuantityRow extends StatelessWidget {
  const QuantityRow({
    super.key,
    required this.leading,
    required this.title,
    required this.price,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.subtitle = '',
  });

  final Widget leading;
  final String title;

  /// What it includes. Left out when empty.
  final String subtitle;
  final String price;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(price, style: AppTextStyles.price),
              ],
            ),
          ),
          const SizedBox(width: 8),
          QuantityStepper(quantity: quantity, onAdd: onAdd, onRemove: onRemove, itemName: title),
        ],
      ),
    );
  }
}
