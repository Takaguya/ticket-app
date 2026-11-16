import 'package:flutter/widgets.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

enum OtpCellState { empty, active, filled, error }

/// One box of the 6-digit code input.
class OtpCell extends StatelessWidget {
  const OtpCell({super.key, required this.digit, required this.state});

  /// The digit shown, or an empty string.
  final String digit;
  final OtpCellState state;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (state) {
      OtpCellState.error => AppColors.error,
      OtpCellState.active => AppColors.primary,
      OtpCellState.filled => AppColors.primaryBorderSoft,
      OtpCellState.empty => AppColors.border,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: AppSizes.otpCellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: digit.isEmpty ? AppColors.surface : AppColors.primarySoft,
        border: Border.all(color: borderColor, width: AppSizes.borderWidth),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
