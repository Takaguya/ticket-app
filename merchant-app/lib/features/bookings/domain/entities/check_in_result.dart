import 'package:equatable/equatable.dart';

import 'booking.dart';

/// The five answers to scanning a QR code or typing a booking ID.
///
/// The server decides this in one atomic step, so two scanners can never
/// both admit the same booking. Only [CheckInAdmitted] lets guests in.
sealed class CheckInResult extends Equatable {
  const CheckInResult();
}

/// Valid and not used before. The whole booking is now checked in.
final class CheckInAdmitted extends CheckInResult {
  const CheckInAdmitted(this.booking);

  /// The booking after check-in.
  final Booking booking;

  @override
  List<Object?> get props => [booking];
}

/// Scanned before. [booking] carries the time and staff name of the first scan.
final class CheckInAlreadyUsed extends CheckInResult {
  const CheckInAlreadyUsed(this.booking);

  final Booking booking;

  @override
  List<Object?> get props => [booking];
}

/// The buyer cancelled this booking.
final class CheckInCancelled extends CheckInResult {
  const CheckInCancelled(this.booking);

  final Booking booking;

  @override
  List<Object?> get props => [booking];
}

/// A real ticket, but for a different event.
final class CheckInOtherEvent extends CheckInResult {
  const CheckInOtherEvent({
    required this.bookingId,
    required this.eventName,
    this.buyerName,
    this.summary,
  });

  final String bookingId;

  /// The event the ticket is actually for.
  final String eventName;
  final String? buyerName;

  /// e.g. `2× Standard seat`
  final String? summary;

  @override
  List<Object?> get props => [bookingId, eventName, buyerName, summary];
}

/// No booking with this ID exists for the event.
final class CheckInNotFound extends CheckInResult {
  const CheckInNotFound(this.bookingId);

  final String bookingId;

  @override
  List<Object?> get props => [bookingId];
}
