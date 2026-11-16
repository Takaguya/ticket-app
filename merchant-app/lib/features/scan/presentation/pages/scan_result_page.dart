import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../bookings/domain/entities/check_in_result.dart';

/// Full-screen answer to a scan: green to admit, red for everything else.
/// Readable at arm's length at a busy entrance.
class ScanResultPage extends StatelessWidget {
  const ScanResultPage({super.key, required this.result, required this.currentUserName});

  final CheckInResult result;

  /// Shown as "you" when this person did the earlier check-in.
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    final view = _ResultView.of(result, currentUserName);
    final color = view.admit ? AppColors.admit : AppColors.reject;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: color,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            view.admit ? Icons.check_rounded : Icons.close_rounded,
                            size: 56,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          view.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: AppColors.surface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          view.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.surface,
                          ),
                        ),
                        if (view.name != null) ...[
                          const SizedBox(height: 24),
                          _BookingCard(view: view),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Scan next',
                      height: 54,
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.ink,
                      onPressed: () => context.pop(),
                    ),
                    if (view.viewableBookingId != null) ...[
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'View booking',
                        height: 48,
                        variant: AppButtonVariant.outline,
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.surface,
                        onPressed: () => context.pushNamed(
                          AppRoutes.booking,
                          pathParameters: {AppRoutes.bookingIdParam: view.viewableBookingId!},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.view});

  final _ResultView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            view.name!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          if (view.detail != null) ...[
            const SizedBox(height: 4),
            Text(view.detail!, style: const TextStyle(fontSize: 14, color: AppColors.textBody)),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFF0F0F0))),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  view.bookingId,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              Text(
                view.note,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The words shown for each of the five scan results.
class _ResultView {
  const _ResultView({
    required this.admit,
    required this.title,
    required this.subtitle,
    required this.bookingId,
    this.note = 'Do not admit',
    this.name,
    this.detail,
    this.viewableBookingId,
  });

  factory _ResultView.of(CheckInResult result, String currentUserName) {
    switch (result) {
      case CheckInAdmitted(:final booking):
        final count = booking.ticketCount;
        return _ResultView(
          admit: true,
          title: 'Admit $count',
          subtitle: count == 1 ? '1 ticket checked in' : 'All $count tickets checked in',
          bookingId: booking.id,
          note: 'Paid · ${booking.payment.label}',
          name: booking.buyerName,
          detail: booking.summary,
          viewableBookingId: booking.id,
        );
      case CheckInAlreadyUsed(:final booking):
        final checkIn = booking.checkIn;
        final by = checkIn?.staffName == currentUserName ? 'you' : checkIn?.staffName;
        return _ResultView(
          admit: false,
          title: 'Already checked in',
          subtitle: checkIn == null
              ? 'This booking was scanned before.'
              : 'Scanned at ${DateFormat.time(checkIn.at)} by $by',
          bookingId: booking.id,
          name: booking.buyerName,
          detail: booking.summary,
          viewableBookingId: booking.id,
        );
      case CheckInCancelled(:final booking):
        final reason = booking.cancellation?.reason;
        return _ResultView(
          admit: false,
          title: 'Booking cancelled',
          subtitle: reason == null
              ? 'This ticket was cancelled and is no longer valid.'
              : 'This ticket was cancelled and is no longer valid.\nReason: ${reason.label}',
          bookingId: booking.id,
          name: booking.buyerName,
          detail: booking.summary,
          viewableBookingId: booking.id,
        );
      case CheckInOtherEvent(:final bookingId, :final eventName, :final buyerName, :final summary):
        return _ResultView(
          admit: false,
          title: 'Ticket for another event',
          subtitle: 'This QR is for $eventName.',
          bookingId: bookingId,
          name: buyerName,
          detail: summary,
        );
      case CheckInNotFound(:final bookingId):
        return _ResultView(
          admit: false,
          title: 'Booking not found',
          subtitle: 'No booking with ID $bookingId for this event.',
          bookingId: bookingId,
        );
    }
  }

  final bool admit;
  final String title;
  final String subtitle;
  final String bookingId;
  final String note;
  final String? name;
  final String? detail;

  /// Set when the booking belongs to this business and can be opened.
  final String? viewableBookingId;
}
