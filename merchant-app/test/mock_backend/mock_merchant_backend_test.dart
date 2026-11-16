// The mock backend applies the handoff's business rules, so these tests also
// describe what the real server must do.

import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/exceptions.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/bookings/domain/entities/check_in_result.dart';
import 'package:merchant/features/bookings/domain/entities/sales_summary.dart';
import 'package:merchant/features/bookings/domain/repositories/bookings_repository.dart';
import 'package:merchant/features/events/domain/entities/event.dart';
import 'package:merchant/features/events/domain/repositories/events_repository.dart';
import 'package:merchant/mock_backend/mock_merchant_backend.dart';

void main() {
  const business = MockMerchantBackend.demoBusinessId;
  final now = DateTime(2026, 11, 12, 9, 30);

  late MockMerchantBackend backend;

  setUp(() => backend = MockMerchantBackend(latency: Duration.zero, clock: () => now));

  Future<List<Booking>> bookings() => backend.watchBookings(business).first;
  Future<List<Event>> events() => backend.watchEvents(business).first;

  Future<Booking> firstWith(String eventId, BookingStatus status) async {
    return (await bookings()).firstWhere((b) => b.eventId == eventId && b.status == status);
  }

  Future<CheckInResult> checkIn(String code, {String eventId = 'e0'}) {
    return backend.checkIn(
      businessId: business,
      eventId: eventId,
      code: code,
      staffName: 'Dara Keo',
    );
  }

  group('check-in', () {
    test('admits a valid booking as a whole, with the time and staff name', () async {
      final open = await firstWith('e0', BookingStatus.open);

      final result = await checkIn(open.id);

      expect(result, isA<CheckInAdmitted>());
      final admitted = (result as CheckInAdmitted).booking;
      expect(admitted.status, BookingStatus.checkedIn);
      expect(admitted.checkIn, CheckIn(at: now, staffName: 'Dara Keo'));
      expect(admitted.ticketCount, open.ticketCount);
    });

    test('accepts the 8 digits alone and adds TK', () async {
      final open = await firstWith('e0', BookingStatus.open);

      expect(await checkIn(open.id.substring(2)), isA<CheckInAdmitted>());
    });

    test('a second scan never admits and shows the first scan', () async {
      final open = await firstWith('e0', BookingStatus.open);
      await checkIn(open.id);

      final second = await backend.checkIn(
        businessId: business,
        eventId: 'e0',
        code: open.id,
        staffName: 'Sreyneang Lim',
      );

      expect(second, isA<CheckInAlreadyUsed>());
      expect((second as CheckInAlreadyUsed).booking.checkIn!.staffName, 'Dara Keo');
    });

    test('a cancelled booking is not admitted', () async {
      final cancelled = await firstWith('e0', BookingStatus.cancelled);

      expect(await checkIn(cancelled.id), isA<CheckInCancelled>());
    });

    test('a booking for another of our events names that event', () async {
      final other = await firstWith('e1', BookingStatus.open);

      final result = await checkIn(other.id);

      expect(result, isA<CheckInOtherEvent>());
      expect((result as CheckInOtherEvent).eventName, 'Kampot River Run 2026');
    });

    test("another business's ticket is for another event", () async {
      expect(await checkIn(MockMerchantBackend.foreignTicketId), isA<CheckInOtherEvent>());
    });

    test('an unknown ID is not found', () async {
      expect(await checkIn('11112222'), const CheckInNotFound('TK11112222'));
    });

    test('check-in only works on the day of the event', () async {
      final upcoming = await firstWith('e1', BookingStatus.open);

      expect(
        () => checkIn(upcoming.id, eventId: 'e1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Check-in opens on the day of the event.',
          ),
        ),
      );
    });
  });

  group('door sale', () {
    final marathon = DoorSaleRequest(
      eventId: 'e0',
      lines: const [BookingLine(ticketType: '10K', quantity: 2)],
      buyerPhone: '+855 12 777 888',
      payment: PaymentMethod.cash,
    );

    test('records a door booking priced from the ticket types', () async {
      final sale = await backend.sellAtDoor(business, marathon);

      expect(sale.channel, SalesChannel.door);
      expect(sale.totalCents, 3600);
      expect(sale.status, BookingStatus.open);
      expect(sale.id, matches(RegExp(r'^TK\d{8}$')));
      expect((await bookings()).first, sale);
    });

    test('is refused when not enough tickets are left', () async {
      final event = await backend.publishEvent(
        business,
        EventDraft(
          name: 'Tiny Gig',
          startsAt: now,
          venue: 'Back room',
          kind: EventKind.show,
          ticketTypes: const [TicketType(name: 'Entry', priceCents: 500, quantity: 1)],
        ),
      );
      final request = DoorSaleRequest(
        eventId: event.id,
        lines: const [BookingLine(ticketType: 'Entry', quantity: 1)],
        buyerPhone: '+855 12 777 888',
        payment: PaymentMethod.cash,
      );

      await backend.sellAtDoor(business, request);

      expect(
        () => backend.sellAtDoor(business, request),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Sold out. No tickets left to sell.',
          ),
        ),
      );
    });
  });

  group('cancelling a booking', () {
    Future<Booking> cancel(String id, {CancelReason reason = CancelReason.buyerAsked}) {
      return backend.cancelBooking(
        businessId: business,
        bookingId: id,
        reason: reason,
        staffName: 'Vannak Sok',
      );
    }

    Matcher refusedWith(int status, String message) {
      return throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', status)
            .having((e) => e.message, 'message', message),
      );
    }

    test('an online booking is refunded in full, with who, when and why', () async {
      final open = await firstWith('e0', BookingStatus.open);

      final cancelled = await cancel(open.id, reason: CancelReason.eventChanged);

      expect(cancelled.status, BookingStatus.cancelled);
      expect(
        cancelled.cancellation,
        Cancellation(
          at: now,
          staffName: 'Vannak Sok',
          reason: CancelReason.eventChanged,
          refundCents: open.totalCents,
        ),
      );
      expect((await bookings()).firstWhere((b) => b.id == open.id), cancelled);
      // The booking leaves the sold numbers and can no longer be admitted.
      expect(cancelled.countsAsSold, isFalse);
      expect(await checkIn(open.id), isA<CheckInCancelled>());
    });

    test('a door sale is refunded by the business itself: Pin refunds 0', () async {
      final sale = await backend.sellAtDoor(
        business,
        const DoorSaleRequest(
          eventId: 'e0',
          lines: [BookingLine(ticketType: '10K', quantity: 1)],
          buyerPhone: '+855 12 777 888',
          payment: PaymentMethod.cash,
        ),
      );

      final cancelled = await cancel(sale.id, reason: CancelReason.soldByMistake);

      expect(cancelled.cancellation!.refundCents, 0);
      expect(cancelled.totalCents, sale.totalCents);
    });

    test('an upcoming event can be cancelled too', () async {
      final upcoming = await firstWith('e1', BookingStatus.open);

      expect((await cancel(upcoming.id)).status, BookingStatus.cancelled);
    });

    test('cancelling again answers the booking unchanged, keeping the first reason', () async {
      final open = await firstWith('e0', BookingStatus.open);
      final first = await cancel(open.id, reason: CancelReason.buyerAsked);

      final again = await cancel(open.id, reason: CancelReason.other);

      expect(again, first);
      expect(again.cancellation!.reason, CancelReason.buyerAsked);
    });

    test('a checked-in booking is refused', () async {
      final admitted = await firstWith('e0', BookingStatus.checkedIn);

      await expectLater(
        cancel(admitted.id),
        refusedWith(409, "This booking is checked in, so it can't be cancelled."),
      );
      expect((await bookings()).firstWhere((b) => b.id == admitted.id).status, BookingStatus.checkedIn);
    });

    test('a booking whose event day has passed is refused', () async {
      final past = await firstWith('e2', BookingStatus.checkedIn);

      await expectLater(cancel(past.id), refusedWith(409, 'The event has ended.'));
    });

    test('an unknown booking is not found', () async {
      await expectLater(cancel('TK11112222'), refusedWith(404, 'This booking does not exist.'));
    });
  });

  group('events', () {
    test('a published event is added to the list', () async {
      final event = await backend.publishEvent(
        business,
        EventDraft(
          name: 'Riverside Night Run',
          startsAt: DateTime(2026, 12, 1, 18, 30),
          venue: 'Riverside',
          kind: EventKind.marathon,
          ticketTypes: const [
            TicketType(name: '5K', priceCents: 1000, quantity: 100),
            TicketType(name: '10K', priceCents: 0, quantity: 50),
          ],
        ),
      );

      expect(event.capacity, 150);
      expect(event.kind, EventKind.marathon);
      expect(await events(), contains(event));
    });

    test('an event without a kind is refused, like the server does', () async {
      await expectLater(
        backend.publishEvent(
          business,
          EventDraft(
            name: 'Kindless',
            startsAt: DateTime(2026, 12, 1, 18, 30),
            venue: 'Riverside',
            ticketTypes: const [TicketType(name: 'Entry', priceCents: 0, quantity: 10)],
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Choose what kind of event it is.'),
        ),
      );
    });
  });

  group('bus trips', () {
    TripDraft trip({
      String origin = 'Phnom Penh',
      String destination = 'Kampot',
      DateTime? startsAt,
      int minutes = 210,
      CoachType coach = CoachType.vip,
    }) {
      return TripDraft(
        origin: origin,
        destination: destination,
        startsAt: startsAt ?? DateTime(2026, 11, 20, 8, 0),
        durationMinutes: minutes,
        coach: coach,
        priceCents: 1600,
        boardingPoint: 'Giant Ibis Terminal',
        amenities: const ['A/C', 'Wi-Fi'],
      );
    }

    Future<void> expectRefused(Future<Object?> call, String message) {
      return expectLater(
        call,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', message),
        ),
      );
    }

    test('a published trip is named after its route and sells one seat per ticket', () async {
      final event = await backend.publishBusTrip(business, trip());

      expect(event.name, 'Phnom Penh to Kampot');
      expect(event.kind, EventKind.bus);
      expect(event.venue, 'Giant Ibis Terminal');
      expect(event.bus?.coach, CoachType.vip);
      expect(event.bus?.durationMinutes, 210);
      expect(event.ticketTypes, [
        const TicketType(name: 'Seat', priceCents: 1600, quantity: 30),
      ]);
      expect(event.capacity, 30);
      expect(await events(), contains(event));
    });

    test('a coach has as many seats as its layout says', () {
      expect(CoachType.seater.seats, 40);
      expect(CoachType.vip.seats, 30);
      expect(CoachType.sleeper.seats, 16);
      expect(CoachType.vip.seatIds.take(4), ['1A', '1B', '1C', '2A']);
      expect(CoachType.sleeper.seatIds.last, '8B');
    });

    test('the route, the journey and the date are checked, like the server does', () async {
      await expectRefused(
        backend.publishBusTrip(business, trip(destination: 'phnom penh')),
        'The trip must go somewhere other than where it starts.',
      );
      await expectRefused(
        backend.publishBusTrip(business, trip(origin: ' ')),
        'Enter where the trip starts.',
      );
      await expectRefused(
        backend.publishBusTrip(business, trip(minutes: 5)),
        'The trip takes between 10 minutes and 24 hours.',
      );
      await expectRefused(
        backend.publishBusTrip(business, trip(startsAt: DateTime(2026, 11, 1))),
        'The event date cannot be in the past.',
      );
    });

    test('a door sale of a trip takes the next free seats, front row first', () async {
      final event = await backend.publishBusTrip(business, trip(coach: CoachType.sleeper));
      Future<Booking> sell(int quantity) => backend.sellAtDoor(
        business,
        DoorSaleRequest(
          eventId: event.id,
          lines: [BookingLine(ticketType: 'Seat', quantity: quantity)],
          buyerPhone: '012000111',
          payment: PaymentMethod.cash,
        ),
      );

      expect((await sell(2)).seats, ['1A', '1B']);
      expect((await sell(1)).seats, ['2A']);
    });
  });

  group('places', () {
    PlaceDraft place({
      String name = 'Garden City Water Park',
      List<PlaceTicketDraft>? tickets,
    }) {
      return PlaceDraft(
        name: name,
        venue: 'Garden City',
        venueDetail: 'Chroy Changvar, Phnom Penh',
        tickets:
            tickets ??
            const [
              PlaceTicketDraft(name: 'Adult', priceCents: 1000, dailyLimit: 5),
              PlaceTicketDraft(name: 'Child', priceCents: 600, description: 'Under 12'),
            ],
      );
    }

    Future<void> expectRefused(Future<Object?> call, String message) {
      return expectLater(
        call,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', message),
        ),
      );
    }

    Future<Booking> sell(String eventId, String ticketType, int quantity) => backend.sellAtDoor(
      business,
      DoorSaleRequest(
        eventId: eventId,
        lines: [BookingLine(ticketType: ticketType, quantity: quantity)],
        buyerPhone: '012000111',
        payment: PaymentMethod.cash,
      ),
    );

    test('a published place is open every day: it has no date, and a limit per day or none', () async {
      final event = await backend.publishPlace(business, place());

      expect(event.kind, EventKind.admission);
      expect(event.isPlace, isTrue);
      expect(event.startsAt, DateTime(2026, 11, 12));
      expect(event.venue, 'Garden City');
      expect(event.ticketTypes, [
        const TicketType(name: 'Adult', priceCents: 1000, quantity: 5),
        const TicketType(name: 'Child', priceCents: 600, quantity: TicketType.noLimit),
      ]);
      expect(event.ticketTypes.map((t) => t.hasLimit), [true, false]);
      expect(await events(), contains(event));
      // Never past: not even long after the day it was published.
      expect(event.timingOn(DateTime(2027, 6, 1)), EventTiming.today);
    });

    test('the name, the venue and the ticket types are checked, like the server does', () async {
      await expectRefused(
        backend.publishPlace(business, place(name: 'Ab')),
        'Give the event a name of at least 3 characters.',
      );
      await expectRefused(
        backend.publishPlace(business, place(tickets: const [])),
        'Add at least one ticket type.',
      );
      await expectRefused(
        backend.publishPlace(
          business,
          place(tickets: const [PlaceTicketDraft(name: 'Adult', priceCents: 0, dailyLimit: 0)]),
        ),
        'A daily limit is at least 1. Leave it empty for no limit.',
      );
    });

    test('a door sale of a place is for today: it keeps its visit day and today\'s limits', () async {
      final event = await backend.publishPlace(business, place());

      final first = await sell(event.id, 'Adult', 4);
      expect(first.visitDate, DateTime(2026, 11, 12));
      await expectLater(
        sell(event.id, 'Adult', 2),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Only 1 left for Adult.')),
      );
      await sell(event.id, 'Adult', 1);
      await expectLater(
        sell(event.id, 'Adult', 1),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Adult is sold out.')),
      );
      // The ticket type with no limit sells on.
      expect((await sell(event.id, 'Child', 8)).visitDate, DateTime(2026, 11, 12));
    });

    test('the numbers of a place are one day\'s visitors', () async {
      final event = await backend.publishPlace(business, place());
      await sell(event.id, 'Adult', 3);
      final today = (await bookings()).firstWhere((b) => b.eventId == event.id);
      final tomorrowsVisitor = Booking(
        id: 'TK99000001',
        eventId: event.id,
        buyerName: 'Sokha Chan',
        phone: '+85510222333',
        lines: const [BookingLine(ticketType: 'Adult', quantity: 4)],
        totalCents: 4000,
        payment: PaymentMethod.abaKhqr,
        channel: SalesChannel.online,
        status: BookingStatus.open,
        visitDate: DateTime(2026, 11, 13),
      );

      final summary = SalesSummary.of(
        event: event,
        bookings: [today, tomorrowsVisitor],
        visitDay: DateTime(2026, 11, 12, 15),
      );
      final allDays = SalesSummary.of(event: event, bookings: [today, tomorrowsVisitor]);

      expect(summary.perDay, isTrue);
      expect(summary.sold, 3);
      expect(summary.byTicketType.first.sold, 3);
      expect(allDays.sold, 7);
    });
  });

  group('cinema screenings', () {
    ScreeningDraft screening({
      String film = 'Skyline Run',
      int minutes = 128,
      String hall = 'Hall 2',
      HallSize size = HallSize.large,
      DateTime? startsAt,
    }) {
      return ScreeningDraft(
        filmTitle: film,
        runtimeMinutes: minutes,
        theatre: 'Legend Cinema, Aeon Mall',
        hall: hall,
        hallSize: size,
        startsAt: startsAt ?? DateTime(2026, 11, 20, 19, 0),
        priceCents: 700,
        rating: 'PG-13',
        genre: 'Action',
      );
    }

    Future<void> expectRefused(Future<Object?> call, String message) {
      return expectLater(
        call,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', message),
        ),
      );
    }

    test('a published screening is named after the film and sells one seat per ticket', () async {
      final event = await backend.publishScreening(business, screening());

      expect(event.name, 'Skyline Run');
      expect(event.kind, EventKind.cinema);
      expect(event.venue, 'Legend Cinema, Aeon Mall');
      expect(event.screening?.hall, 'Hall 2');
      expect(event.screening?.hallSize, HallSize.large);
      expect(event.screening?.runtimeMinutes, 128);
      expect(event.ticketTypes, [
        const TicketType(name: 'Seat', priceCents: 700, quantity: 120),
      ]);
      expect(event.capacity, 120);
      expect(await events(), contains(event));
    });

    test('a hall has as many seats as its size says, lettered from the front', () {
      expect(HallSize.small.seats, 48);
      expect(HallSize.standard.seats, 80);
      expect(HallSize.large.seats, 120);
      expect(HallSize.small.seatIds.take(3), ['A1', 'A2', 'A3']);
      expect(HallSize.standard.seatIds[10], 'B1');
      expect(HallSize.large.seatIds.last, 'J12');
      expect(HallSize.standard.label, 'Standard · 80 seats');
    });

    test('the film, the hall and the date are checked, like the server does', () async {
      await expectRefused(
        backend.publishScreening(business, screening(film: ' ')),
        "Enter the film's title.",
      );
      await expectRefused(
        backend.publishScreening(business, screening(minutes: 5)),
        'The film runs between 10 minutes and 10 hours.',
      );
      await expectRefused(
        backend.publishScreening(business, screening(hall: '')),
        'Enter the hall, e.g. Hall 3.',
      );
      await expectRefused(
        backend.publishScreening(business, screening(startsAt: DateTime(2026, 11, 1))),
        'The event date cannot be in the past.',
      );
    });

    test('a door sale of a screening takes the next free seats, front row first', () async {
      final event = await backend.publishScreening(business, screening(size: HallSize.small));
      Future<Booking> sell(int quantity) => backend.sellAtDoor(
        business,
        DoorSaleRequest(
          eventId: event.id,
          lines: [BookingLine(ticketType: 'Seat', quantity: quantity)],
          buyerPhone: '012000111',
          payment: PaymentMethod.cash,
        ),
      );

      expect((await sell(3)).seats, ['A1', 'A2', 'A3']);
      expect((await sell(1)).seats, ['A4']);
    });
  });

  group('staff', () {
    test('a join code adds a scanner to that business', () async {
      expect(backend.businessIdForJoinCode('482 913'), business);

      backend.addScanner(businessId: business, memberId: 'u_9', name: 'Mony Chea');

      final team = await backend.watchTeam(business).first;
      expect(team.members.map((m) => m.name), contains('Mony Chea'));
    });

    test('a new join code replaces the old one', () async {
      final code = await backend.regenerateJoinCode(business);

      expect(code, isNot(MockMerchantBackend.demoJoinCode));
      expect(backend.businessIdForJoinCode(MockMerchantBackend.demoJoinCode), isNull);
      expect(backend.businessIdForJoinCode(code), business);
    });

    test('a scanner can be removed but the owner cannot', () async {
      await backend.removeMember(business, 'u_2');
      final team = await backend.watchTeam(business).first;
      expect(team.members.map((m) => m.id), isNot(contains('u_2')));

      expect(() => backend.removeMember(business, 'u_1'), throwsA(isA<ApiException>()));
    });
  });
}
