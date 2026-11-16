import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';

/// Round badge with a person's initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 42,
    this.backgroundColor = AppColors.primarySoft,
    this.foregroundColor = AppColors.primary,
  });

  final String initials;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size / 3,
          fontWeight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
    );
  }
}
