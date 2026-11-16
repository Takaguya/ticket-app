import 'package:flutter/painting.dart';

/// Colours taken from the Pin user app prototype (the same brand as Pin Merchant).
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
  static const background = Color(0xFFF5F5F5);
  static const fill = Color(0xFFF2F2F2);
  static const border = Color(0xFFE0E0E0);
  static const borderSoft = Color(0xFFE6E6E6);
  static const divider = Color(0xFFECECEC);
  static const disabled = Color(0xFFECECEC);
  static const onDisabled = Color(0xFF666666);

  // Status
  static const success = Color(0xFF2E9E43);
  static const successSoft = Color(0xFFE7F5EA);
  static const danger = Color(0xFFE5484D);
  static const dangerSoft = Color(0xFFFDEAEA);
  static const warning = Color(0xFF9A7000);
  static const warningSoft = Color(0xFFFDF4CE);
  static const error = Color(0xFFE5484D);

  // Ticket categories: tag background and foreground
  static const eventSoft = Color(0xFFFDEAEA);
  static const event = Color(0xFFE5484D);
  static const busSoft = Color(0xFFEAF1FB);
  static const bus = Color(0xFF1258AC);
  static const cinemaSoft = Color(0xFF1A1A1A);
  static const cinema = Color(0xFFFFD400);
  static const admissionSoft = Color(0xFFFDF4CE);
  static const admission = Color(0xFF9A7000);

  // Home services
  static const rideSoft = Color(0xFFE8F4F2);
  static const ride = Color(0xFF1F8A5B);

  // Seat maps
  static const seatBorder = Color(0xFFCCCCCC);
  static const seatTaken = Color(0xFFE0E0E0);
  static const onSeatTaken = Color(0xFFAAAAAA);
  static const seatFemaleSoft = Color(0xFFFCE7F0);
  static const seatFemaleBorder = Color(0xFFF4B6D0);
  static const seatFemale = Color(0xFFC2185B);
  static const seatMaleSoft = Color(0xFFE3EDFA);
  static const seatMaleBorder = Color(0xFFB9D0F0);
  static const seatMale = Color(0xFF1258AC);
}
