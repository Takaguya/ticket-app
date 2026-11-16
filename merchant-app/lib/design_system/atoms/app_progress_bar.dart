import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';

/// Horizontal bar filled to [value] (0 to 1).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.trackColor = AppColors.primarySoft,
    this.color = AppColors.primary,
  });

  final double value;
  final double height;
  final Color trackColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final fraction = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    return Semantics(
      label: '${(fraction * 100).round()} percent',
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: ColoredBox(
            color: trackColor,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction),
                duration: const Duration(milliseconds: 300),
                builder: (context, animated, _) => FractionallySizedBox(
                  widthFactor: animated,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: color, borderRadius: radius),
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
