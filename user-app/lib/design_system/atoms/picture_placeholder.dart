import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Stands in for a poster, banner or hero picture until listings have images:
/// a soft fill with an icon and, optionally, a caption.
class PicturePlaceholder extends StatelessWidget {
  const PicturePlaceholder({
    super.key,
    this.caption,
    this.icon = Icons.image_outlined,
    this.color = AppColors.textMuted,
  });

  final String? caption;
  final IconData icon;

  /// Colour of the icon; the fill is a pale shade of it.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color.alphaBlend(color.withValues(alpha: 0.08), AppColors.fill),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: color.withValues(alpha: 0.7)),
              if (caption != null) ...[
                const SizedBox(height: 8),
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
