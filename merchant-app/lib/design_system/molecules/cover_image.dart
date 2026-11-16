import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// An event's cover image, fetched from its address.
///
/// Shows [fallback] when there is no [url], while the picture loads, and if it
/// cannot be loaded (no connection, or the picture was removed meanwhile), so a
/// missing picture never leaves a broken-image icon or a hole in the layout.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.radius = 12,
  });

  final String? url;

  /// What to show instead of a picture; give it the same size as this widget.
  final Widget fallback;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final address = url;
    if (address == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          address,
          fit: BoxFit.cover,
          // The same address is a new picture only when its version changes.
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(color: AppColors.fill, child: SizedBox.expand());
          },
        ),
      ),
    );
  }
}
