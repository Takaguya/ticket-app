import 'package:equatable/equatable.dart';

/// Money for online bookings: what buyers paid, Pin's commission, and what the
/// business gets. Door sales are paid to the business directly and never
/// count here.
class PayoutAmount extends Equatable {
  const PayoutAmount({
    required this.grossCents,
    required this.commissionCents,
    required this.netCents,
    required this.bookingCount,
    this.refundsCents = 0,
  });

  static const zero = PayoutAmount(grossCents: 0, commissionCents: 0, netCents: 0, bookingCount: 0);

  final int grossCents;
  final int commissionCents;

  /// The business's share of paid-out bookings it has cancelled since, taken
  /// off this amount.
  final int refundsCents;

  /// Can be below zero while refunds are more than new sales: nothing is owed
  /// then, and the rest comes off the next payout.
  final int netCents;
  final int bookingCount;

  @override
  List<Object?> get props => [grossCents, commissionCents, refundsCents, netCents, bookingCount];
}

/// Money Pin sent the business.
class Payout extends Equatable {
  const Payout({required this.id, required this.paidAt, required this.amount});

  final String id;

  /// Local to Pin's time zone.
  final DateTime paidAt;
  final PayoutAmount amount;

  @override
  List<Object?> get props => [id, paidAt, amount];
}

/// What Pin owes the business now, and what it has paid lately.
class PayoutsOverview extends Equatable {
  const PayoutsOverview({required this.due, required this.paid});

  /// Online bookings no payout covers yet.
  final PayoutAmount due;

  /// The latest payouts, newest first.
  final List<Payout> paid;

  @override
  List<Object?> get props => [due, paid];
}
