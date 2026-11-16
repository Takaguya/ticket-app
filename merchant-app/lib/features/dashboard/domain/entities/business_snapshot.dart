import 'package:equatable/equatable.dart';

import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/entities/sales_summary.dart';
import '../../../events/domain/entities/event.dart';

/// Everything the main screens show, at one moment: the business's events
/// and bookings, and the time they are judged against.
class BusinessSnapshot extends Equatable {
  const BusinessSnapshot({required this.events, required this.bookings, required this.asOf});

  final List<Event> events;
  final List<Booking> bookings;

  /// "Now" for deciding which events are past, today or upcoming.
  final DateTime asOf;

  /// The event happening today, if any. Only its bookings can be checked in.
  /// One that Pin has approved comes before one still waiting: only it can sell,
  /// and a business with several places is always "open today" in all of them.
  Event? get liveEvent {
    final today = events.where((e) => e.timingOn(asOf) == EventTiming.today).toList()
      ..sort((a, b) {
        if (a.approved != b.approved) return a.approved ? -1 : 1;
        return a.startsAt.compareTo(b.startsAt);
      });
    return today.isEmpty ? null : today.first;
  }

  /// Soonest first. A place is open every day, so it is always here, after
  /// the events that have a date, in the order it was published.
  List<Event> get upcomingEvents {
    final dated = events.where((e) => e.timingOn(asOf) == EventTiming.upcoming).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final places = events.where((e) => e.isPlace).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return [...dated, ...places];
  }

  /// Most recent first.
  List<Event> get pastEvents {
    return events.where((e) => e.timingOn(asOf) == EventTiming.past).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  Event? eventById(String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  Booking? bookingById(String id) {
    for (final booking in bookings) {
      if (booking.id == id) return booking;
    }
    return null;
  }

  List<Booking> bookingsOf(String eventId) {
    return bookings.where((b) => b.eventId == eventId).toList();
  }

  /// An event's numbers. A place has no day of its own, so its numbers are
  /// today's visitors, as the server counts them.
  SalesSummary summaryOf(Event event) =>
      SalesSummary.of(event: event, bookings: bookings, visitDay: asOf);

  /// The newest check-ins for an event, latest first.
  List<Booking> latestCheckIns(String eventId, {int limit = 5}) {
    final admitted =
        bookings.where((b) => b.eventId == eventId && b.checkIn != null && b.countsAsSold).toList()
          ..sort((a, b) => b.checkIn!.at.compareTo(a.checkIn!.at));
    return admitted.take(limit).toList();
  }

  /// Online bookings here that [previous] did not have: people who booked in
  /// the Pin user app since then. Door sales are made on this device and are
  /// left out.
  List<Booking> newOnlineBookingsSince(BusinessSnapshot previous) {
    final known = {for (final booking in previous.bookings) booking.id};
    return bookings
        .where((b) => b.channel == SalesChannel.online && !known.contains(b.id))
        .toList();
  }

  /// Bookings a staff member has admitted for an event.
  int scansBy(String staffName, String eventId) {
    return bookings
        .where((b) => b.eventId == eventId && b.checkIn?.staffName == staffName)
        .length;
  }

  @override
  List<Object?> get props => [events, bookings, asOf];
}
