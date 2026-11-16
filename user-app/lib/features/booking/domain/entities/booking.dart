import 'package:equatable/equatable.dart';

import '../../../../core/utils/date_format.dart';
import 'booking_cancellation.dart';
import 'booking_request.dart';
import 'order.dart';

/// Tickets that have been paid for and issued.
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.request,
    required this.holderName,
    required this.paidWith,
    required this.totalCents,
    required this.bookedAt,
    this.promoCode,
    this.discountCents = 0,
    this.status = BookingStatus.confirmed,
    this.cancellation,
  });

  /// `TK` and 8 digits, e.g. `TK48213377`. Printed on the ticket and held by
  /// its QR code, which staff scan at the entrance.
  final String id;

  /// What was bought.
  final BookingRequest request;

  /// Whose name the tickets are in: the account holder, or the runner.
  final String holderName;
  final PaymentMethod paidWith;
  final String? promoCode;
  final int discountCents;

  /// What was paid, in whole US cents.
  final int totalCents;
  final DateTime bookedAt;

  /// Buyers cannot cancel; only the business can, which sets [cancellation].
  final BookingStatus status;

  /// Set when [status] is [BookingStatus.cancelled].
  final BookingCancellation? cancellation;

  bool get isCancelled => status == BookingStatus.cancelled;
  bool get isUsed => status == BookingStatus.used;

  /// Upcoming until the end of the day it is for, then past.
  bool isPastAt(DateTime now) {
    return DateFormat.dateOnly(request.startsAt).isBefore(DateFormat.dateOnly(now));
  }

  @override
  List<Object?> get props => [
    id,
    request,
    holderName,
    paidWith,
    promoCode,
    discountCents,
    totalCents,
    bookedAt,
    status,
    cancellation,
  ];
}
