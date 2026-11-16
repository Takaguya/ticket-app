import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Rounded filter option with an optional count, black when selected.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.surface : const Color(0xFF333333);
    final radius = BorderRadius.circular(18);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.inkSoft : AppColors.fill,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            // widthFactor keeps the pill as wide as its label.
            child: Center(
              widthFactor: 1,
              child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (count != null)
                    TextSpan(
                      text: '  $count',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
