import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../../events/domain/entities/event.dart';
import 'booking.dart';

/// Sold and checked-in counts for one ticket type.
class TicketTypeStats extends Equatable {
  const TicketTypeStats({required this.name, required this.sold, required this.checkedIn});

  final String name;
  final int sold;
  final int checkedIn;

  double get checkedInFraction => sold == 0 ? 0 : checkedIn / sold;

  @override
  List<Object?> get props => [name, sold, checkedIn];
}

/// The numbers behind the Today and Finance screens for one event.
///
/// Rules: cancelled bookings count for nothing. Commission is a percentage
/// of online sales only; door sales have none. The business receives the
/// total minus commission.
class SalesSummary extends Equatable {
  const SalesSummary({
    required this.capacity,
    required this.sold,
    required this.checkedIn,
    required this.bookingCount,
    required this.onlineCents,
    required this.doorCents,
    required this.commissionCents,
    required this.commissionRate,
    required this.byTicketType,
    this.perDay = false,
  });

  /// [visitDay] is the day a place's numbers are for, as the server counts
  /// them: only the bookings for that day. Ignored for any other event.
  factory SalesSummary.of({
    required Event event,
    required Iterable<Booking> bookings,
    DateTime? visitDay,
  }) {
    bool forTheDay(Booking b) {
      if (!event.isPlace || visitDay == null) return true;
      final visit = b.visitDate;
      return visit != null &&
          visit.year == visitDay.year &&
          visit.month == visitDay.month &&
          visit.day == visitDay.day;
    }

    final counted = bookings
        .where((b) => b.eventId == event.id && b.countsAsSold && forTheDay(b))
        .toList();
    final admitted = counted.where((b) => b.status == BookingStatus.checkedIn).toList();
    int tickets(Iterable<Booking> list) => list.fold(0, (sum, b) => sum + b.ticketCount);
    int cents(Iterable<Booking> list) => list.fold(0, (sum, b) => sum + b.totalCents);

    return SalesSummary(
      capacity: event.capacity,
      perDay: event.isPlace,
      sold: tickets(counted),
      checkedIn: tickets(admitted),
      bookingCount: counted.length,
      onlineCents: cents(counted.where((b) => b.channel == SalesChannel.online)),
      doorCents: cents(counted.where((b) => b.channel == SalesChannel.door)),
      commissionCents: counted.fold(
        0,
        (sum, b) => sum + commissionOf(b, event.commissionRate),
      ),
      commissionRate: event.commissionRate,
      byTicketType: [
        for (final type in event.ticketTypes)
          TicketTypeStats(
            name: type.name,
            sold: counted.fold(0, (sum, b) => sum + b.quantityOf(type.name)),
            checkedIn: admitted.fold(0, (sum, b) => sum + b.quantityOf(type.name)),
          ),
      ],
    );
  }

  /// Pin's commission on one booking, in cents.
  static int commissionOf(Booking booking, double rate) {
    if (!booking.countsAsSold || booking.channel == SalesChannel.door) return 0;
    return Money.percentOf(booking.totalCents, rate);
  }

  final int capacity;

  /// A place: the numbers are one day's visitors, and [capacity] is a limit
  /// per day, not a total.
  final bool perDay;

  /// Tickets sold, excluding cancelled bookings.
  final int sold;

  /// Tickets admitted so far.
  final int checkedIn;
  final int bookingCount;
  final int onlineCents;
  final int doorCents;
  final int commissionCents;
  final double commissionRate;
  final List<TicketTypeStats> byTicketType;

  int get revenueCents => onlineCents + doorCents;
  int get netCents => revenueCents - commissionCents;

  /// Tickets that can still be sold. Door sale is blocked at 0.
  int get left => math.max(0, capacity - sold);
  int get stillToArrive => sold - checkedIn;
  double get checkedInFraction => sold == 0 ? 0 : checkedIn / sold;

  @override
  List<Object?> get props => [
    capacity,
    perDay,
    sold,
    checkedIn,
    bookingCount,
    onlineCents,
    doorCents,
    commissionCents,
    commissionRate,
    byTicketType,
  ];
}
