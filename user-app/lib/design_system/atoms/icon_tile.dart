import 'package:flutter/widgets.dart';

enum IconTileShape { circle, rounded }

/// An icon on a soft coloured background: the category circles, the home
/// services and the date and place rows of a detail page.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 40,
    this.shape = IconTileShape.rounded,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final IconTileShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: shape == IconTileShape.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape == IconTileShape.rounded ? BorderRadius.circular(size * 0.28) : null,
      ),
      child: Icon(icon, size: size * 0.48, color: foreground),
    );
  }
}
