import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/picture_placeholder.dart';
import '../../../../design_system/molecules/remote_image.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/presentation/category_style.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_cancellation.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/entities/order.dart';
import '../booking_text.dart';

/// The ticket itself: what and when, whose, and the QR code staff scan. The
/// QR code holds the booking ID, which Pin Merchant's scanner reads.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.booking, required this.isPast});

  final Booking booking;

  /// The day has gone: the ticket shows "Ended".
  final bool isPast;

  List<(String, String)> get _facts {
    final request = booking.request;
    final date = DateFormat.long(request.startsAt);
    final name = ('NAME', booking.holderName);
    return switch (request) {
      EventRequest(:final runner) => [
        ('DATE', date),
        ('TIME', request.timeText),
        ('VENUE', request.place),
        ('TYPE', request.ticketsText),
        name,
        if (runner != null) ('T-SHIRT', runner.shirtSize.label) else ('TICKETS', request.ticketCountText),
      ],
      AdmissionRequest() => [
        ('DATE', date),
        ('ENTRY', 'All day'),
        ('PLACE', request.place),
        ('TYPE', request.ticketsText),
        name,
        ('TICKETS', request.ticketCountText),
      ],
      BusRequest(:final departure, :final seats) => [
        ('DATE', date),
        ('DEPARTS', DateFormat.time(departure.departsAt)),
        ('FROM', departure.boardingPoint),
        ('SEATS', seats.map((seat) => seat.id).join(', ')),
        name,
        ('OPERATOR', departure.operatorName),
      ],
      CinemaRequest(:final showtime, :final seats, :final snacks) => [
        ('DATE', date),
        ('TIME', request.timeText),
        ('CINEMA', request.place),
        ('SEATS', '${showtime.hall} · ${seats.map((seat) => seat.id).join(', ')}'),
        name,
        (
          'SNACKS',
          snacks.entries.where((e) => e.value > 0).isEmpty
              ? 'None'
              : [
                  for (final MapEntry(key: snack, value: n) in snacks.entries)
                    if (n > 0) '$n× ${snack.name}',
                ].join(', '),
        ),
      ],
    };
  }

  String get _scanHint {
    if (booking.isUsed) return 'Used: already scanned at the entrance';
    return switch (booking.request) {
      BusRequest(:final seats) =>
        'Show this when you board · ${seats.length == 1 ? '1 seat' : '${seats.length} seats'}',
      CinemaRequest() => 'Scan at the cinema entrance · snacks at the counter',
      EventRequest() || AdmissionRequest() =>
        'Scan at the entrance · valid for ${booking.request.ticketCountText}',
    };
  }

  /// Cancelled and used say more than whether the day has gone.
  Widget _statusBadge() {
    if (booking.isCancelled) {
      return const AppBadge(
        label: 'Cancelled',
        backgroundColor: AppColors.danger,
        foregroundColor: AppColors.surface,
      );
    }
    if (booking.isUsed) {
      return const AppBadge(
        label: 'Used',
        backgroundColor: AppColors.fill,
        foregroundColor: AppColors.textMuted,
      );
    }
    return isPast
        ? const AppBadge(
            label: 'Ended',
            backgroundColor: AppColors.fill,
            foregroundColor: AppColors.textMuted,
          )
        : const AppBadge(
            label: 'Confirmed',
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.surface,
          );
  }

  @override
  Widget build(BuildContext context) {
    final request = booking.request;
    final category = request.category;
    final facts = _facts;
    final cancellation = booking.isCancelled ? booking.cancellation : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RemoteImage(
                    path: request.imageUrl,
                    fallback: PicturePlaceholder(caption: request.title, icon: request.icon, color: category.color),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _statusBadge(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  request.tagBadge(),
                  const SizedBox(height: 6),
                  Text(request.title, style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  for (var i = 0; i < facts.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Fact(label: facts[i].$1, value: facts[i].$2)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: i + 1 < facts.length
                                ? _Fact(label: facts[i + 1].$1, value: facts[i + 1].$2)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Column(
                children: [
                  // A cancelled ticket admits no one, so it has no QR code, with
                  // or without the details of the cancellation.
                  if (booking.isCancelled)
                    cancellation != null
                        ? _CancelledNotice(cancellation: cancellation, paidWith: booking.paidWith)
                        : const _CancelledPlainNotice()
                  else ...[
                    Opacity(
                      opacity: isPast || booking.isUsed ? 0.35 : 1,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: booking.id,
                          size: 176,
                          padding: EdgeInsets.zero,
                          semanticsLabel: 'QR code for booking ${booking.id}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SelectableText(
                    booking.id,
                    style: AppTextStyles.title.copyWith(fontSize: 18, letterSpacing: 1.5),
                  ),
                  if (!booking.isCancelled)
                    Text(_scanHint, textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who cancelled the booking and when, why, and the money paid back.
class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice({required this.cancellation, required this.paidWith});

  final BookingCancellation cancellation;
  final PaymentMethod paidWith;

  @override
  Widget build(BuildContext context) {
    final refund = cancellation.refundCents > 0
        ? 'Refunded ${Money.format(cancellation.refundCents)} to ${paidWith.label}'
        : 'Nothing to refund';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancelled by ${cancellation.businessName} on ${DateFormat.full(cancellation.at)}',
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 4),
          Text(cancellation.reason.label, style: AppTextStyles.body),
          const SizedBox(height: 4),
          Text(refund, style: AppTextStyles.bodyStrong),
          const SizedBox(height: 4),
          const Text('This ticket no longer admits anyone.', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

/// A cancelled booking the server gave no details for.
class _CancelledPlainNotice extends StatelessWidget {
  const _CancelledPlainNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Cancelled by the organiser.',
        style: AppTextStyles.bodyStrong.copyWith(color: AppColors.danger),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyStrong),
      ],
    );
  }
}

/// The torn-off line between the details and the QR code.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dashes = (constraints.maxWidth / 10).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < dashes; i++)
                      const SizedBox(
                        width: 5,
                        height: 1.5,
                        child: ColoredBox(color: AppColors.border),
                      ),
                  ],
                );
              },
            ),
          ),
          const Positioned(left: -10, child: _Notch()),
          const Positioned(right: -10, child: _Notch()),
        ],
      ),
    );
  }
}

/// A half circle cut into the ticket's edge.
class _Notch extends StatelessWidget {
  const _Notch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
    );
  }
}
