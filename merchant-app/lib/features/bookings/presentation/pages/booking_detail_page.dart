import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/key_value_row.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../dashboard/presentation/bloc/business/business_bloc.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/sales_summary.dart';
import '../bloc/cancel_booking/cancel_booking_bloc.dart';
import '../bloc/check_in/check_in_bloc.dart';
import '../organisms/booking_status_badge.dart';
import '../organisms/cancel_booking_sheet.dart';

/// One booking in full, with a "Check in" button while it can be admitted and,
/// for owners, a "Cancel booking" button while it is open. Expects
/// [BusinessBloc] and a [CheckInBloc] above it, and a [CancelBookingBloc] when
/// [canCancel].
class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({
    super.key,
    required this.bookingId,
    required this.currentUserName,
    required this.showMoney,
    required this.canCancel,
  });

  final String bookingId;

  /// Shown as "you" when this person did the check-in.
  final String currentUserName;

  /// Commission and "You receive" are for owners only.
  final bool showMoney;

  /// Only owners cancel bookings.
  final bool canCancel;

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessBloc>().state;
    final snapshot = business.snapshot;
    final booking = snapshot?.bookingById(bookingId);
    final event = booking == null ? null : snapshot?.eventById(booking.eventId);

    if (business.status == BusinessStatus.loading) {
      return const Scaffold(backgroundColor: AppColors.background, body: MessageView.loading());
    }
    if (snapshot == null || booking == null || event == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            ScreenHeader(title: bookingId, onBack: () => context.pop()),
            const Expanded(
              child: MessageView(
                icon: Icons.search_off_rounded,
                title: 'Booking not found',
                message: 'It may belong to another event.',
              ),
            ),
          ],
        ),
      );
    }

    final timing = _timingOf(booking, event, snapshot.asOf);
    final canCheckIn = booking.status == BookingStatus.open && timing == EventTiming.today;
    final showCancel =
        canCancel && booking.status == BookingStatus.open && timing != EventTiming.past;
    final colors = bookingStatusColors(booking.status);
    final promoCode = booking.promoCode;
    final runner = booking.runner;

    return BlocListener<CheckInBloc, CheckInState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CheckInStatus.failure) {
          AppToast.show(context, state.errorMessage ?? 'Something went wrong');
        }
        if (state.status != CheckInStatus.decided) return;
        AppToast.show(context, switch (state.result) {
          CheckInAdmitted(:final booking) => '${ticketsLabel(booking.ticketCount)} checked in',
          CheckInAlreadyUsed() => 'Already checked in',
          CheckInCancelled() => 'This booking was cancelled',
          _ => 'This booking cannot be checked in',
        });
        context.read<CheckInBloc>().add(const CheckInCleared());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            ScreenHeader(
              title: booking.id,
              onBack: () => context.pop(),
              trailing: BookingStatusBadge(status: booking.status),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 20),
                children: [
                  _BuyerCard(booking: booking),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Column(children: _facts(booking, event)),
                  ),
                  if (promoCode != null) ...[
                    const SizedBox(height: 8),
                    Text('Promo $promoCode · paid by Pin', style: AppTextStyles.caption),
                  ],
                  if (runner != null) ...[
                    const SizedBox(height: 12),
                    _RunnerCard(runner: runner),
                  ],
                  const SizedBox(height: 12),
                  AppCard(
                    color: colors.background,
                    radius: AppRadii.control,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      _note(booking, timing),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: colors.foreground,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (showCancel) ...[
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Cancel booking',
                      variant: AppButtonVariant.outline,
                      foregroundColor: AppColors.danger,
                      onPressed: () => _openCancelSheet(context, booking),
                    ),
                  ],
                ],
              ),
            ),
            if (canCheckIn)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 14),
                    child: BlocBuilder<CheckInBloc, CheckInState>(
                      builder: (context, state) => AppButton(
                        label: 'Check in ${ticketsLabel(booking.ticketCount)}',
                        loading: state.status == CheckInStatus.checking,
                        onPressed: () => context.read<CheckInBloc>().add(
                          CheckInRequested(eventId: booking.eventId, code: booking.id),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCancelSheet(BuildContext context, Booking booking) async {
    final cancelled = await showCancelBookingSheet(
      context,
      bloc: context.read<CancelBookingBloc>(),
      booking: booking,
    );
    if (cancelled == true && context.mounted) AppToast.show(context, 'Booking cancelled');
  }

  List<Widget> _facts(Booking booking, Event event) {
    final commission = SalesSummary.commissionOf(booking, event.commissionRate);
    final showCommission =
        showMoney && booking.countsAsSold && booking.channel == SalesChannel.online;
    final rate = event.commissionRate;
    final rateLabel = rate == rate.roundToDouble() ? '${rate.round()}' : '$rate';

    final facts = [
      (switch (event.kind) {
        EventKind.bus => 'Trip',
        EventKind.cinema => 'Film',
        EventKind.admission => 'Place',
        _ => 'Event',
      }, event.name),
      if (booking.visitDate != null) ('Visit date', DateFormat.full(booking.visitDate!)),
      if (booking.seats.isNotEmpty)
        (booking.seats.length == 1 ? 'Seat' : 'Seats', booking.seats.join(', ')),
      if (booking.tshirtSizes.isNotEmpty)
        (
          booking.tshirtSizes.length == 1 ? 'T-shirt size' : 'T-shirt sizes',
          booking.tshirtSizes.join(', '),
        ),
      ('Sold', booking.channel.label),
      ('Payment', booking.payment.label),
      ('Total', Money.format(booking.totalCents)),
      if (showCommission) ...[
        ('Pin commission ($rateLabel%)', '−${Money.format(commission)}'),
        ('You receive', Money.format(booking.totalCents - commission)),
      ],
    ];
    return [
      for (final (index, (label, value)) in facts.indexed)
        KeyValueRow(label: label, value: value, showDivider: index < facts.length - 1),
    ];
  }

  String _note(Booking booking, EventTiming timing) {
    final checkIn = booking.checkIn;
    return switch (booking.status) {
      BookingStatus.checkedIn when checkIn != null =>
        'Checked in at ${DateFormat.time(checkIn.at)} by '
            '${checkIn.staffName == currentUserName ? 'you' : checkIn.staffName}',
      BookingStatus.checkedIn => 'Checked in',
      BookingStatus.cancelled => _cancelledNote(booking),
      BookingStatus.open => switch (timing) {
        EventTiming.past => booking.visitDate == null
            ? 'Did not check in. The event has ended.'
            : 'Did not check in. The ticket was for ${DateFormat.full(booking.visitDate!)}.',
        EventTiming.upcoming => booking.visitDate == null
            ? 'Check-in opens on the day of the event.'
            : 'The ticket is for ${DateFormat.full(booking.visitDate!)}. Check-in opens that day.',
        EventTiming.today =>
          booking.ticketCount == 1
              ? 'Not checked in yet.'
              : 'Not checked in yet. All ${booking.ticketCount} tickets on this booking are '
                    'admitted together.',
      },
    };
  }
}

/// When this booking's tickets are good, as the server decides: a place is open
/// every day, but a ticket to it is good on its visit day only. Any other
/// booking is good when its event is.
EventTiming _timingOf(Booking booking, Event event, DateTime now) {
  final visit = booking.visitDate;
  if (visit == null) return event.timingOn(now);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(visit.year, visit.month, visit.day);
  if (day.isBefore(today)) return EventTiming.past;
  return day.isAfter(today) ? EventTiming.upcoming : EventTiming.today;
}

/// Who cancelled, why, and what happens to the buyer's money. Bookings
/// cancelled before the app recorded this have no details.
String _cancelledNote(Booking booking) {
  final cancellation = booking.cancellation;
  if (cancellation == null) return 'Cancelled. Do not admit.';
  final at = cancellation.at;
  final money = booking.channel == SalesChannel.door
      ? 'Give the buyer their ${Money.format(booking.totalCents)} back'
      : 'Pin refunded the buyer ${Money.format(cancellation.refundCents)}';
  return 'Cancelled by ${cancellation.staffName} · ${DateFormat.full(at)} ${DateFormat.time(at)}\n'
      '${cancellation.reason.label}\n'
      '$money';
}

/// A race runner's details, for the whole team.
class _RunnerCard extends StatelessWidget {
  const _RunnerCard({required this.runner});

  final Runner runner;

  @override
  Widget build(BuildContext context) {
    final email = runner.email;
    final rows = [
      ('Name', runner.name),
      ('Phone', PhoneNumber.display(runner.phone)),
      if (email != null && email.isNotEmpty) ('Email', email),
      ('Gender', _capitalised(runner.gender)),
      ('Age', '${runner.age}'),
      ('Nationality', runner.nationality),
      (
        'Emergency contact',
        '${runner.emergencyName} · ${PhoneNumber.display(runner.emergencyPhone)}',
      ),
      ('T-shirt size', runner.shirtSize),
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Runner', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 2),
          for (final (index, (label, value)) in rows.indexed)
            KeyValueRow(label: label, value: value, showDivider: index < rows.length - 1),
        ],
      ),
    );
  }

  static String _capitalised(String text) {
    return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
  }
}

class _BuyerCard extends StatelessWidget {
  const _BuyerCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            booking.buyerName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            PhoneNumber.display(booking.phone),
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFF0F0F0))),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${booking.ticketCount}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.summary,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
