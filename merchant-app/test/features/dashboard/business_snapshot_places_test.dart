import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/dashboard/domain/entities/business_snapshot.dart';
import 'package:merchant/features/events/domain/entities/event.dart';

/// A place is open every day: it is today's event whatever day it was published,
/// and it never ends.
void main() {
  final asOf = DateTime(2026, 11, 20, 14);

  Event place(String id, {DateTime? publishedOn}) => Event(
    id: id,
    name: 'Place $id',
    kind: EventKind.admission,
    startsAt: publishedOn ?? DateTime(2026, 11, 2),
    venue: 'Somewhere',
    ticketTypes: const [TicketType(name: 'Adult', priceCents: 500, quantity: 5)],
  );

  Booking visit(String id, String eventId, DateTime day, {int adults = 2}) => Booking(
    id: id,
    eventId: eventId,
    buyerName: 'Sokha Chan',
    phone: '+85510222333',
    lines: [BookingLine(ticketType: 'Adult', quantity: adults)],
    totalCents: adults * 500,
    payment: PaymentMethod.card,
    channel: SalesChannel.online,
    status: BookingStatus.open,
    visitDate: day,
  );

  test('a place published long ago is still live today, and upcoming, never past', () {
    final snapshot = BusinessSnapshot(events: [place('a'), place('b')], bookings: const [], asOf: asOf);

    expect(snapshot.liveEvent?.id, 'a');
    expect(snapshot.upcomingEvents.map((e) => e.id), ['a', 'b']);
    expect(snapshot.pastEvents, isEmpty);
  });

  test('events with a date come first among the upcoming; places after them', () {
    final concert = Event(
      id: 'c',
      name: 'Concert',
      startsAt: DateTime(2026, 12, 1, 19),
      venue: 'Hall',
      ticketTypes: const [TicketType(name: 'Standard', priceCents: 1500, quantity: 100)],
    );
    final snapshot = BusinessSnapshot(events: [place('a'), concert], bookings: const [], asOf: asOf);

    expect(snapshot.upcomingEvents.map((e) => e.id), ['c', 'a']);
  });

  test('a place\'s numbers are today\'s visitors, whoever booked for another day', () {
    final visited = place('a');
    final today = DateTime(2026, 11, 20);
    final snapshot = BusinessSnapshot(
      events: [visited],
      bookings: [
        visit('TK00000001', 'a', today, adults: 3),
        visit('TK00000002', 'a', DateTime(2026, 11, 21), adults: 4),
        visit('TK00000003', 'a', DateTime(2026, 11, 19), adults: 1),
      ],
      asOf: asOf,
    );

    final summary = snapshot.summaryOf(visited);

    expect(summary.perDay, isTrue);
    expect(summary.sold, 3);
    expect(summary.revenueCents, 1500);
  });
}
