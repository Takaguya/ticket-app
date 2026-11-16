import 'package:equatable/equatable.dart';

/// Where a booking stands.
enum BookingStatus {
  /// Paid and valid.
  confirmed,

  /// Scanned at the entrance (the server's "checked in").
  used,

  /// Cancelled by the business that sells the tickets. It no longer admits anyone.
  cancelled,
}

/// Why a business cancelled a booking, in the words the buyer reads.
enum CancellationReason {
  buyerAsked('You asked to cancel'),
  eventChanged('The event changed or was called off'),
  soldByMistake('Sold by mistake'),
  other('Other reason');

  const CancellationReason(this.label);

  final String label;
}

/// A booking the business cancelled, and what the buyer got back.
class BookingCancellation extends Equatable {
  const BookingCancellation({
    required this.at,
    required this.reason,
    required this.businessName,
    required this.refundCents,
  });

  final DateTime at;
  final CancellationReason reason;

  /// Who cancelled, e.g. "PP Live Events".
  final String businessName;

  /// Paid back to how the buyer paid, in whole US cents. Everything they paid.
  final int refundCents;

  @override
  List<Object?> get props => [at, reason, businessName, refundCents];
}
