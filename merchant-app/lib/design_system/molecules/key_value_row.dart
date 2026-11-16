import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';

/// A label on the left and its value on the right, with a thin divider
/// underneath unless it is the last row.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.showDivider = true,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool showDivider;

  /// Larger, bolder styling for a total such as "You receive".
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: emphasized ? 12 : 11.5),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.dividerSoft))
            : null,
      ),
      // Label and value each take what they need, up to half the row, and
      // spaceBetween keeps the value against the right edge however short
      // the label is. Longer texts wrap instead of pushing the other off.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              label,
              style: emphasized
                  ? const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    )
                  : const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: emphasized
                  ? const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    )
                  : const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
