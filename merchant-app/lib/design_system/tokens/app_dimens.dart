/// Spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal page padding on dashboard screens.
  static const double page = 16;

  /// Horizontal page padding on sign-in screens.
  static const double pageWide = 24;
}

/// Corner radii.
abstract final class AppRadii {
  static const double badge = 8;
  static const double segment = 11;
  static const double input = 12;
  static const double control = 14;
  static const double card = 16;
  static const double chip = 22;
  static const double pill = 24;
}

/// Fixed sizes shared by several components.
abstract final class AppSizes {
  /// Smallest comfortable tap target.
  static const double tapTarget = 44;
  static const double buttonHeight = 52;
  static const double fieldHeight = 54;
  static const double otpCellHeight = 56;
  static const double borderWidth = 1.5;
}
