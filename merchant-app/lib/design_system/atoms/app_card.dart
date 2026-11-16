import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// White rounded panel that groups related content on a grey screen.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.surface,
    this.radius = AppRadii.card,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  /// Adds the soft blue shadow used by the main "Checked in" card.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x1A00315E), blurRadius: 18, offset: Offset(0, 6))]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
