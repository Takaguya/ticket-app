import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/selectable_chip.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/booking.dart';
import '../bloc/cancel_booking/cancel_booking_bloc.dart';

/// Opens the sheet where the owner picks why a booking is cancelled and
/// confirms. Returns true once the booking was cancelled, null when the sheet
/// is dismissed. [bloc] is owned by the caller.
Future<bool?> showCancelBookingSheet(
  BuildContext context, {
  required CancelBookingBloc bloc,
  required Booking booking,
}) {
  bloc.add(const CancelSheetOpened());
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: CancelBookingSheet(booking: booking),
    ),
  );
}

/// "Why are you cancelling?": the four reasons, what happens to the money, and
/// the confirm button. Expects a [CancelBookingBloc] above it.
class CancelBookingSheet extends StatelessWidget {
  const CancelBookingSheet({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CancelBookingBloc, CancelBookingState>(
      listenWhen: (previous, current) => !previous.cancelled && current.cancelled,
      listener: (context, state) => Navigator.of(context).pop(true),
      builder: (context, state) {
        final message = state.errorMessage;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 20, AppSpacing.page, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Why are you cancelling?', style: AppTextStyles.screenTitle.copyWith(fontSize: 17)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final reason in CancelReason.values)
                      SelectableChip(
                        label: reason.label,
                        selected: reason == state.reason,
                        // The reason is fixed while the request is on its way.
                        onTap: state.submitting
                            ? () {}
                            : () => context.read<CancelBookingBloc>().add(CancelReasonChosen(reason)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(_moneyLine(booking), style: AppTextStyles.bodySmall),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(message, style: AppTextStyles.error),
                ],
                const SizedBox(height: 14),
                AppButton(
                  label: 'Cancel booking',
                  height: 50,
                  loading: state.submitting,
                  // Looks muted until a reason is chosen, but still answers a tap.
                  active: state.reason != null,
                  backgroundColor: state.reason == null ? null : AppColors.danger,
                  onPressed: () => context.read<CancelBookingBloc>().add(const CancelConfirmed()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// What happens to the buyer's money.
  static String _moneyLine(Booking booking) {
    return booking.channel == SalesChannel.door
        ? 'Give the buyer their ${Money.format(booking.totalCents)} back yourself.'
        : 'Pin refunds the buyer in full, to how they paid.';
  }
}
