import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/features/catalog/domain/entities/ticket_category.dart';
import 'package:user/mock_backend/mock_catalog.dart';

void main() {
  // Sunday 15 Nov 2026, 08:00.
  final now = DateTime(2026, 11, 15, 8);
  final catalog = MockCatalog(clock: FixedClock(now));

  test('events lie ahead, soonest first, so the demo never runs out', () {
    final events = catalog.inCategory(TicketCategory.events).cast<EventListing>();

    expect(events.map((e) => e.name).first, 'Khmer Rock Night 2026');
    expect(events.first.startsAt, DateTime(2026, 11, 22, 19));
    for (var i = 1; i < events.length; i++) {
      expect(events[i].startsAt.isAfter(events[i - 1].startsAt), isTrue);
    }
    expect(events.every((e) => e.startsAt.isAfter(now)), isTrue);
  });

  test('from price is the cheapest paid ticket', () {
    final angkor = catalog.byId('ad1')!;
    // Adults $37, children free.
    expect(angkor.fromPriceCents, 3700);
    expect(catalog.byId('ev1')!.fromPriceCents, 1500);
  });

  test('buses that have already left today are not offered', () {
    final today = catalog.departures(origin: 'Phnom Penh', destination: 'Siem Reap', date: now);
    final tomorrow = catalog.departures(
      origin: 'Phnom Penh',
      destination: 'Siem Reap',
      date: now.add(const Duration(days: 1)),
    );

    expect(today.map((d) => d.operatorName), isNot(contains('Giant Ibis')));
    expect(today, hasLength(3));
    expect(tomorrow, hasLength(4));
    expect(tomorrow.first.operatorName, 'Giant Ibis');
    expect(tomorrow.first.priceCents, 1500);
  });

  test('a route can be travelled both ways, with only as many operators as it has', () {
    final back = catalog.departures(
      origin: 'Battambang',
      destination: 'Phnom Penh',
      date: now.add(const Duration(days: 1)),
    );

    expect(back, hasLength(2));
    expect(back.first.origin, 'Battambang');
    expect(back.first.destination, 'Phnom Penh');
    expect(
      catalog.departures(origin: 'Kampot', destination: 'Siem Reap', date: now),
      isEmpty,
    );
  });

  test('showtimes that have started are not offered', () {
    final today = catalog.showtimes(filmId: 'cn1', date: now.add(const Duration(hours: 12)));
    final times = [
      for (final theatre in today)
        for (final show in theatre.showtimes) show.startsAt.hour,
    ];

    // At 20:00 only the 20:30 and 21:30 screenings are left.
    final evening = MockCatalog(clock: FixedClock(DateTime(2026, 11, 15, 20)));
    final late = evening.showtimes(filmId: 'cn1', date: now);
    expect(late.map((t) => t.theatre.id), ['aeon1', 'exch']);
    expect(times, contains(10));
    expect(catalog.showtimes(filmId: 'ev1', date: now), isEmpty);
  });

  test('search matches names and places, ignoring case', () {
    expect(catalog.search('KAMPOT').map((l) => l.name), ['Phnom Penh → Kampot']);
    expect(catalog.search('siem reap').map((l) => l.id), containsAll(['ev3', 'bs1', 'ad1']));
    expect(catalog.search('   '), isEmpty);
  });
}
