import 'package:flutter/widgets.dart';

import '../tokens/app_dimens.dart';

/// Cards two to a row. Both cards in a row are as tall as the taller one, so
/// names of one and two lines still line up.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.spacing = AppSpacing.sm});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) SizedBox(height: spacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                SizedBox(width: spacing),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Cards of a set width in a row that scrolls sideways, all as tall as the
/// tallest.
class CardCarousel extends StatelessWidget {
  const CardCarousel({
    super.key,
    required this.children,
    required this.cardWidth,
    this.spacing = AppSpacing.sm,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
  });

  final List<Widget> children;
  final double cardWidth;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              SizedBox(width: cardWidth, child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}
