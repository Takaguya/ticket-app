import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/error/exceptions.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/auth/domain/entities/gender.dart';
import 'package:user/features/auth/domain/entities/pin_user.dart';
import 'package:user/features/booking/domain/entities/booking_cancellation.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/domain/entities/order.dart';
import 'package:user/features/booking/domain/entities/runner_details.dart';
import 'package:user/features/booking/domain/entities/seat_map.dart';
import 'package:user/features/catalog/domain/entities/bus_departure.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/mock_backend/mock_bookings.dart';
import 'package:user/mock_backend/mock_catalog.dart';

void main() {
  // Sunday 15 Nov 2026, 08:00.
  final now = DateTime(2026, 11, 15, 8);
  final sokha = PinUser(
    id: 'u_1',
    name: 'Sokha Chan',
    phone: '+85510222333',
    gender: Gender.female,
    dateOfBirth: DateTime(1996, 4, 12),
  );
  final dara = PinUser(
    id: 'u_2',
    name: 'Dara Pich',
    phone: '+85512888999',
    gender: Gender.male,
    dateOfBirth: DateTime(1990, 1, 1),
  );

  late MockCatalog catalog;
  late MockBookings bookings;

  setUp(() {
    catalog = MockCatalog(clock: FixedClock(now));
    bookings = MockBookings(catalog: catalog);
  });

  List<BusDeparture> toSiemReap() {
    return catalog.departures(origin: 'Phnom Penh', destination: 'Siem Reap', date: now);
  }

  Iterable<Seat> seatsOf(SeatMap map) => map.rows.expand((row) => row).nonNulls;

  Matcher rejectedWith(String text) {
    return throwsA(isA<ApiException>().having((e) => e.message, 'message', contains(text)));
  }

  test('a bus has as many free seats as its departure says are left', () {
    for (final departure in toSiemReap()) {
      final free = seatsOf(bookings.busSeats(departure)).where((s) => !s.status.isTaken);
      expect(free, hasLength(departure.seatsLeft), reason: departure.operatorName);
    }
  });

  test('the seat layout follows the coach: 2+2, a VIP van 2+1, a sleeper 1+1', () {
    final maps = {for (final d in toSiemReap()) d.operatorCode: bookings.busSeats(d)};

    expect(maps['LR']!.rows, hasLength(10));
    expect(maps['LR']!.rows.first.map((s) => s?.id), ['1A', '1B', null, '1C', '1D']);
    expect(maps['VB']!.rows.first.map((s) => s?.id), ['1A', null, '1B', '1C']);
    expect(maps['ME']!.rows, hasLength(8));
    expect(maps['ME']!.rows.first.map((s) => s?.id), ['1A', null, '1B']);
    expect(maps['LR']!.seat('1A')!.detail, 'Row 1 · Window');
    expect(maps['LR']!.seat('1B')!.detail, 'Row 1 · Aisle');
  });

  test("seats sold show the buyer's gender and cannot be sold twice", () {
    final departure = toSiemReap().firstWhere((d) => d.operatorCode == 'VB');
    final two = seatsOf(bookings.busSeats(departure)).where((s) => !s.status.isTaken).take(2).toList();
    final order = Order(
      request: BusRequest(departure: departure, seats: two),
      paymentMethod: PaymentMethod.abaPay,
    );

    final booking = bookings.place(sokha, order);

    expect(booking.id, matches(RegExp(r'^TK\d{8}$')));
    expect(booking.totalCents, 2 * departure.priceCents);
    for (final seat in two) {
      expect(bookings.busSeats(departure).seat(seat.id)!.status, SeatStatus.takenByFemale);
    }
    expect(() => bookings.place(dara, order), rejectedWith('has just been taken'));
  });

  test('a bus that has left cannot be booked', () {
    // Seen at 07:00, booked at 08:00: the 07:45 Giant Ibis has gone.
    final earlier = MockCatalog(clock: FixedClock(DateTime(2026, 11, 15, 7)));
    final giantIbis = earlier
        .departures(origin: 'Phnom Penh', destination: 'Siem Reap', date: now)
        .firstWhere((d) => d.operatorCode == 'GI');
    final seat = seatsOf(bookings.busSeats(giantIbis)).firstWhere((s) => !s.status.isTaken);

    expect(
      () => bookings.place(
        dara,
        Order(
          request: BusRequest(departure: giantIbis, seats: [seat]),
          paymentMethod: PaymentMethod.card,
        ),
      ),
      rejectedWith('already left'),
    );
  });

  test(r'promo codes: 10% off, or $2 off an order of $5 or more', () {
    final rock = catalog.byId('ev1')! as EventListing;
    final tamao = catalog.byId('ad3')! as AdmissionListing;
    Order rockNight(int tickets, String code) => Order(
      request: EventRequest(event: rock, quantities: {rock.tiers.first: tickets}),
      paymentMethod: PaymentMethod.card,
      promoCode: code,
    );

    // $30 less 10%, and $15 less $2.
    expect(bookings.place(dara, rockNight(2, 'd2d10')).totalCents, 2700);
    expect(bookings.place(dara, rockNight(1, 'FIRST')).totalCents, 1300);
    expect(() => bookings.place(dara, rockNight(1, 'NOPE')), rejectedWith('not a valid promo code'));

    // A $2 child ticket is too little for FIRST.
    final child = Order(
      request: AdmissionRequest(attraction: tamao, day: now, quantities: {tamao.tiers.last: 1}),
      paymentMethod: PaymentMethod.abaPay,
      promoCode: 'FIRST',
    );
    expect(() => bookings.place(dara, child), rejectedWith(r'$5.00 or more'));
  });

  test('a race needs its runner, and can keep the details for next time', () {
    final race = catalog.byId('ev2')! as EventListing;
    final request = EventRequest(event: race, quantities: {race.tiers.last: 1});
    const runner = RunnerDetails(
      name: 'Sokha Chan',
      phone: '+85510222333',
      gender: Gender.female,
      age: 30,
      nationality: 'Cambodian',
      emergencyName: 'Vanna Chan',
      emergencyPhone: '+85512345678',
      shirtSize: ShirtSize.m,
    );

    expect(
      () => bookings.place(sokha, Order(request: request, paymentMethod: PaymentMethod.abaPay)),
      rejectedWith("runner's details"),
    );

    final booking = bookings.place(
      sokha,
      Order(request: request.withRunner(runner), paymentMethod: PaymentMethod.abaPay, saveRunner: true),
    );
    expect(booking.holderName, 'Sokha Chan');
    expect(bookings.savedRunner(sokha), runner);
    expect(bookings.savedRunner(dara), isNull);
  });

  test('the demo account starts with a past bus trip, a film in two days and a cancelled rock night', () {
    final demo = bookings.bookingsOf(sokha);

    expect(demo.map((b) => b.id), ['TK30571942', 'TK48213377', 'TK55012468']);
    final [trip, filmBooking, rockNight] = demo;
    expect(trip.isPastAt(now), isTrue);
    expect(filmBooking.isPastAt(now), isFalse);
    // Two $5.50 seats and a $6.50 popcorn combo.
    expect(filmBooking.totalCents, 1750);
    final film = filmBooking.request as CinemaRequest;
    expect(film.showtime.startsAt, DateTime(2026, 11, 17, 18, 45));
    expect(bookings.cinemaSeats(film.showtime).seat('F5')!.status, SeatStatus.taken);
    expect([trip, filmBooking].map((b) => b.status), everyElement(BookingStatus.confirmed));

    expect(bookings.bookingsOf(dara), isEmpty);

    // The organiser cancelled it yesterday and paid the two $15 tickets back.
    expect(rockNight.status, BookingStatus.cancelled);
    expect(rockNight.request.title, 'Khmer Rock Night 2026');
    final cancellation = rockNight.cancellation!;
    expect(cancellation.businessName, 'PP Live Events');
    expect(cancellation.reason, CancellationReason.eventChanged);
    expect(cancellation.at, DateTime(2026, 11, 14, 8));
    expect(cancellation.refundCents, 3000);
    expect(cancellation.refundCents, rockNight.totalCents);
  });
}
