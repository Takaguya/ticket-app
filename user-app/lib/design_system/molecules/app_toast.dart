import 'package:flutter/material.dart';

/// Short message at the bottom of the screen. Styling comes from the theme's
/// snack bar settings.
abstract final class AppToast {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Text(message, textAlign: TextAlign.center),
        ),
      );
  }
}
