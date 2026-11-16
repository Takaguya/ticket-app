import 'package:flutter/widgets.dart';

import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../domain/entities/booking.dart';

/// Background and text colour for a booking status.
({Color background, Color foreground}) bookingStatusColors(BookingStatus status) {
  return switch (status) {
    BookingStatus.checkedIn => (background: AppColors.successSoft, foreground: AppColors.success),
    BookingStatus.open => (background: AppColors.primarySoft, foreground: AppColors.primary),
    BookingStatus.cancelled => (background: AppColors.dangerSoft, foreground: AppColors.danger),
  };
}

/// "Checked in", "Not checked in" or "Cancelled" in the matching colour.
class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = bookingStatusColors(status);
    return AppBadge(
      label: status.label,
      backgroundColor: colors.background,
      foregroundColor: colors.foreground,
    );
  }
}
