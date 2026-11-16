import 'package:flutter/painting.dart';

/// Colours taken from the Pin Merchant and Pin user app prototypes.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF0151A6);
  static const primarySoft = Color(0xFFE8F1FB);
  static const primaryBorderSoft = Color(0xFFB9D0F0);
  static const accent = Color(0xFFFFD400);

  // Text
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF1A1A1A);
  static const textBody = Color(0xFF444444);
  static const textSecondary = Color(0xFF555555);
  static const textMuted = Color(0xFF666666);
  static const textSubtle = Color(0xFF6B6B6B);
  static const placeholder = Color(0xFFB5B5B5);

  // Surfaces and lines
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F6F6);
  static const fill = Color(0xFFF2F2F2);
  static const border = Color(0xFFE0E0E0);
  static const divider = Color(0xFFECECEC);
  static const dividerSoft = Color(0xFFF4F4F4);
  static const disabled = Color(0xFFECECEC);
  static const onDisabled = Color(0xFF666666);

  // Status
  static const success = Color(0xFF1D7A32);
  static const successBright = Color(0xFF2E9E43);
  static const successSoft = Color(0xFFE7F5EA);
  static const danger = Color(0xFFC0363A);
  static const dangerSoft = Color(0xFFFDEAEA);

  /// Waiting for Pin, e.g. a business or event not approved yet.
  static const warning = Color(0xFF6B5000);
  static const warningSoft = Color(0xFFFDF4CE);
  static const error = Color(0xFFE5484D);

  // Full-screen scan results
  static const admit = Color(0xFF1F8A5B);
  static const reject = Color(0xFFD13438);

  // Dark scanner screen
  static const dark = Color(0xFF111111);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkRaised = Color(0xFF2C2C2E);
  static const darkBorder = Color(0xFF48484A);
  static const onDarkMuted = Color(0xFFC8C8C8);
}
