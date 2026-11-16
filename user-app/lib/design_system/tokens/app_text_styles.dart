import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Type scale from the prototype. The system font (Roboto on Android) is used.
abstract final class AppTextStyles {
  static const display = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const screenTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const bodyStrong = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const bodySmall = TextStyle(
    fontSize: 13,
    color: AppColors.textMuted,
    height: 1.4,
  );

  static const caption = TextStyle(
    fontSize: 12.5,
    color: AppColors.textSubtle,
    height: 1.5,
  );

  static const fieldLabel = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textSubtle,
    letterSpacing: 0.6,
  );

  static const input = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);

  static const link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  static const price = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const badge = TextStyle(fontSize: 11, fontWeight: FontWeight.w800);

  static const error = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.error,
  );
}
