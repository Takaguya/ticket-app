import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';

/// Circle with a person's initials, e.g. "SC" for Sokha Chan.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 52});

  final String name;
  final double size;

  /// The first letters of the first and last words, at most two.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return '';
    final letters = words.length == 1 ? [words.first] : [words.first, words.last];
    return letters.map((word) => word.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.33,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
