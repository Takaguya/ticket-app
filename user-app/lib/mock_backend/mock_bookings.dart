import 'dart:async';
import 'dart:math';

import '../core/error/exceptions.dart';
import '../core/utils/clock.dart';
import '../core/utils/date_format.dart';
import '../core/utils/money.dart';
import '../features/auth/data/datasources/auth_mock_data_source.dart';
import '../features/auth/domain/entities/gender.dart';
import '../features/auth/domain/entities/pin_user.dart';
import '../features/booking/domain/entities/booking.dart';
import '../features/booking/domain/entities/booking_cancellation.dart';
import '../features/booking/domain/entities/booking_request.dart';
import '../features/booking/domain/entities/order.dart';
import '../features/booking/domain/entities/promotion.dart';
import '../features/booking/domain/entities/runner_details.dart';
import '../features/booking/domain/entities/seat_map.dart';
import '../features/booking/domain/entities/snack.dart';
import '../features/catalog/domain/entities/bus_departure.dart';
import '../features/catalog/domain/entities/listing.dart';
import '../features/catalog/domain/entities/showtime.dart';
import 'mock_catalog.dart';

/// The booking side of the Pin user app prototype, in memory: seat maps,
/// snacks, promo codes and each account's bookings, which last until the app
/// restarts.
///
/// The demo account (Sokha Chan) starts with a cinema booking two days ahead,
/// a bus trip taken twelve days ago and a rock night its organiser cancelled.
class MockBookings {
  MockBookings({required this.catalog, Random? random}) : _random = random ?? Random();

  final MockCatalog catalog;
  final Random _random;

  /// Bookings by account ID.
  final _bookings = <String, List<Booking>>{};

  /// Saved runner details by account ID.
  final _runners = <String, RunnerDetails>{};

  /// Seats sold here, by departure or showtime ID, and who sits in each.
  final _sold = <String, Map<String, Gender>>{};

  final _changes = StreamController<String>.broadcast();

  static const snacks = [
    Snack(
      id: 'popcorn-combo',
      name: 'Popcorn combo',
      description: 'Large popcorn + 2 drinks',
      priceCents: 650,
    ),
    Snack(id: 'sweet-popcorn', name: 'Sweet popcorn', description: 'Regular', priceCents: 300),
    Snack(id: 'nachos', name: 'Nachos & cheese', description: 'Regular', priceCents: 400),
    Snack(id: 'soft-drink', name: 'Soft drink', description: 'Regular · Coke / Sprite', priceCents: 150),
  ];

  static const promotions = [
    Promotion(code: 'D2D10', title: '10% off tickets', description: 'Any category', percentOff: 10),
    Promotion(
      code: 'FIRST',
      title: r'$2 off',
      description: r'Orders of $5 or more',
      amountOffCents: 200,
      minimumSpendCents: 500,
    ),
  ];

  Clock get clock => catalog.clock;

  /// The ID of each account whose bookings change.
  Stream<String> get changes => _changes.stream;

  // ------------------------------------------------------------ seat maps

  /// A coach's seats: 10 rows of 2+2, 10 rows of 2+1 in a VIP van, or 8 rows
  /// of 1+1 beds on a night sleeper. As many are free as the departure says
  /// are left, fewer once some are sold here; which ones depends on the day.
  SeatMap busSeats(BusDeparture departure) {
    final type = departure.coachType.toLowerCase();
    final sleeper = type.contains('sleeper');
    final vip = type.contains('2+1');
    final columns = sleeper
        ? const ['A', null, 'B']
        : vip
        ? const ['A', null, 'B', 'C']
        : const ['A', 'B', null, 'C', 'D'];
    final rowCount = sleeper ? 8 : 10;
    final sold = _sold[departure.id] ?? const <String, Gender>{};
    final seed = departure.departsAt.day * 31 + departure.operatorCode.codeUnitAt(0);

    // The seats not sold here, shuffled the same way all day: the first are taken.
    final unsold = [
      for (var row = 1; row <= rowCount; row++)
        for (final column in columns.nonNulls)
          if (!sold.containsKey('$row$column')) '$row$column',
    ]..sort((a, b) => _scramble(a, seed).compareTo(_scramble(b, seed)));
    final capacity = rowCount * columns.nonNulls.length;
    final takenBefore = unsold.take(capacity - min(departure.seatsLeft, capacity)).toSet();

    SeatStatus statusOf(String id) {
      final gender = sold[id];
      if (gender != null) return _takenBy(gender);
      if (!takenBefore.contains(id)) return SeatStatus.available;
      return _scramble(id, seed + 1).isEven ? SeatStatus.takenByFemale : SeatStatus.takenByMale;
    }

    return SeatMap(
      seatType: sleeper
          ? 'Sleeper · 1+1'
          : vip
          ? 'VIP seater · 2+1'
          : 'Seater · standard · 2+2',
      priceCents: departure.priceCents,
      rows: [
        for (var row = 1; row <= rowCount; row++)
          [
            for (final (index, column) in columns.indexed)
              if (column == null)
                null
              else
                Seat(
                  id: '$row$column',
                  label: '$row$column',
                  detail: 'Row $row · '
                      '${index == 0 || index == columns.length - 1 ? 'Window' : 'Aisle'}',
                  status: statusOf('$row$column'),
                ),
          ],
      ],
    );
  }

  /// A hall of 8 rows, A to H, of 10 seats in blocks of 3, 4 and 3. About one
  /// seat in five is taken, and those sold here.
  SeatMap cinemaSeats(Showtime showtime) {
    const columns = [1, 2, 3, null, 4, 5, 6, 7, null, 8, 9, 10];
    final sold = _sold[showtime.id] ?? const <String, Gender>{};
    final seed = showtime.startsAt.day + showtime.startsAt.hour;
    return SeatMap(
      seatType: showtime.hall,
      priceCents: showtime.priceCents,
      hasScreen: true,
      rows: [
        for (var row = 0; row < 8; row++)
          [
            for (final (index, number) in columns.indexed)
              if (number == null)
                null
              else
                Seat(
                  id: '${_rowLetter(row)}$number',
                  label: '$number',
                  detail: 'Row ${_rowLetter(row)}',
                  status:
                      sold.containsKey('${_rowLetter(row)}$number') ||
                          (row * 7 + index * 13 + seed) % 5 == 0
                      ? SeatStatus.taken
                      : SeatStatus.available,
                ),
          ],
      ],
    );
  }

  // ------------------------------------------------------------- bookings

  /// The account's bookings, soonest first.
  List<Booking> bookingsOf(PinUser user) {
    return [..._bookingsOf(user)]
      ..sort((a, b) => a.request.startsAt.compareTo(b.request.startsAt));
  }

  Booking? booking(PinUser user, String id) {
    for (final booking in _bookingsOf(user)) {
      if (booking.id == id) return booking;
    }
    return null;
  }

  RunnerDetails? savedRunner(PinUser user) => _runners[user.id];

  /// Takes the payment and issues the tickets, after the checks the server
  /// makes: something chosen, not started, seats still free, the runner
  /// named, a valid promo code. Prices are worked out here, not taken from
  /// the app.
  Booking place(PinUser user, Order order) {
    final request = order.request;
    final now = clock.now();

    if (request.ticketCount == 0) _reject('Choose at least one ticket.');
    final started = request is AdmissionRequest
        ? request.startsAt.isBefore(DateFormat.dateOnly(now))
        : !request.startsAt.isAfter(now);
    if (started) {
      _reject(
        request is BusRequest
            ? 'This bus has already left. Choose another departure.'
            : 'This has already started.',
      );
    }

    final (String? scheduleId, SeatMap? seatMap, List<Seat> seats) = switch (request) {
      BusRequest(:final departure, :final seats) => (departure.id, busSeats(departure), seats),
      CinemaRequest(:final showtime, :final seats) => (showtime.id, cinemaSeats(showtime), seats),
      EventRequest() || AdmissionRequest() => (null, null, const <Seat>[]),
    };
    if (seats.length > SeatMap.maxSeatsPerBooking) {
      _reject('Choose at most ${SeatMap.maxSeatsPerBooking} seats per booking.');
    }
    for (final seat in seats) {
      if (seatMap?.seat(seat.id)?.status != SeatStatus.available) {
        _reject('Seat ${seat.id} has just been taken. Choose another seat.');
      }
    }

    final runner = request is EventRequest ? request.runner : null;
    if (request is EventRequest && request.event.needsRunnerDetails && runner == null) {
      _reject("Add the runner's details.");
    }

    final subtotal = request.subtotalCents;
    Promotion? promotion;
    final code = order.promoCode;
    if (code != null) {
      promotion = promotions.where((p) => p.matches(code)).firstOrNull;
      if (promotion == null) _reject('$code is not a valid promo code.');
      if (!promotion.appliesTo(subtotal)) {
        _reject(
          '${promotion.code} needs an order of ${Money.format(promotion.minimumSpendCents)} or more.',
        );
      }
    }
    final discount = promotion?.discountOn(subtotal) ?? 0;

    final booking = Booking(
      id: _newId(),
      request: request,
      holderName: runner?.name ?? user.name,
      paidWith: order.paymentMethod,
      promoCode: promotion?.code,
      discountCents: discount,
      totalCents: subtotal - discount,
      bookedAt: now,
    );
    _bookingsOf(user).add(booking);
    if (scheduleId != null) {
      final taken = _sold.putIfAbsent(scheduleId, () => {});
      for (final seat in seats) {
        taken[seat.id] = user.gender;
      }
    }
    if (order.saveRunner && runner != null) _runners[user.id] = runner;
    _changes.add(user.id);
    return booking;
  }

  List<Booking> _bookingsOf(PinUser user) {
    return _bookings.putIfAbsent(
      user.id,
      () => user.phone == AuthMockDataSource.demoPhone ? _demoBookings(user) : [],
    );
  }

  /// Neak Ta at Exchange Square in two days (seats F5 and F6 and a popcorn
  /// combo), a Giant Ibis bus to Kampot twelve days ago, and two Khmer Rock
  /// Night tickets in a week that PP Live Events cancelled yesterday.
  List<Booking> _demoBookings(PinUser user) {
    final now = clock.now();
    final today = DateFormat.dateOnly(now);

    final film = catalog.byId('cn1')! as FilmListing;
    final showDay = DateTime(today.year, today.month, today.day + 2);
    final theatre = catalog
        .showtimes(filmId: film.id, date: showDay)
        .firstWhere((theatre) => theatre.theatre.id == 'exch');
    final showtime = theatre.showtimes.firstWhere((show) => show.hall == 'Hall 3');
    final cinema = CinemaRequest(
      film: film,
      theatre: theatre.theatre,
      showtime: showtime,
      seats: const [
        Seat(id: 'F5', label: '5', detail: 'Row F'),
        Seat(id: 'F6', label: '6', detail: 'Row F'),
      ],
      snacks: {snacks.first: 1},
    );
    _sold[showtime.id] = {'F5': user.gender, 'F6': user.gender};

    final tripDay = DateTime(today.year, today.month, today.day - 12);
    final bus = BusRequest(
      departure: BusDeparture(
        id: 'bs3-GI-${tripDay.year}${tripDay.month}${tripDay.day}',
        routeId: 'bs3',
        operatorName: 'Giant Ibis',
        operatorCode: 'GI',
        operatorColor: 0xFF1E8A72,
        coachType: 'Luxury coach · 2+2',
        origin: 'Phnom Penh',
        destination: 'Kampot',
        departsAt: DateTime(tripDay.year, tripDay.month, tripDay.day, 7, 45),
        duration: const Duration(hours: 3, minutes: 30),
        priceCents: 1100,
        amenities: const ['Wi-Fi', 'A/C', 'Snack'],
        seatsLeft: 9,
        boardingPoint: 'Giant Ibis / Virak Buntham Terminal',
        boardingAddress: 'St 106, Riverside, Phnom Penh',
      ),
      seats: const [
        Seat(id: '5A', label: '5A', detail: 'Row 5 · Window'),
        Seat(id: '5B', label: '5B', detail: 'Row 5 · Aisle'),
      ],
    );

    // Khmer Rock Night in a week, cancelled yesterday by its organiser, who
    // paid everything back.
    final rock = catalog.byId('ev1')! as EventListing;
    final rockNight = EventRequest(event: rock, quantities: {rock.tiers.first: 2});

    return [
      Booking(
        id: 'TK48213377',
        request: cinema,
        holderName: user.name,
        paidWith: PaymentMethod.abaPay,
        totalCents: cinema.subtotalCents,
        bookedAt: now.subtract(const Duration(days: 1)),
      ),
      Booking(
        id: 'TK30571942',
        request: bus,
        holderName: user.name,
        paidWith: PaymentMethod.card,
        totalCents: bus.subtotalCents,
        bookedAt: tripDay.subtract(const Duration(days: 3)),
      ),
      Booking(
        id: 'TK55012468',
        request: rockNight,
        holderName: user.name,
        paidWith: PaymentMethod.abaPay,
        totalCents: rockNight.subtotalCents,
        bookedAt: now.subtract(const Duration(days: 4)),
        status: BookingStatus.cancelled,
        cancellation: BookingCancellation(
          at: now.subtract(const Duration(days: 1)),
          reason: CancellationReason.eventChanged,
          businessName: rock.organiser,
          refundCents: rockNight.subtotalCents,
        ),
      ),
    ];
  }

  /// `TK` and 8 digits, not used yet.
  String _newId() {
    while (true) {
      final id = 'TK${10000000 + _random.nextInt(90000000)}';
      if (!_bookings.values.any((list) => list.any((booking) => booking.id == id))) return id;
    }
  }

  Never _reject(String message) {
    throw ApiException(code: ApiErrorCodes.rejected, message: message, statusCode: 409);
  }

  static SeatStatus _takenBy(Gender gender) {
    return switch (gender) {
      Gender.female => SeatStatus.takenByFemale,
      Gender.male => SeatStatus.takenByMale,
      Gender.other => SeatStatus.taken,
    };
  }

  static String _rowLetter(int row) => String.fromCharCode(65 + row);

  /// A number below 9999 that looks random but is always the same for the
  /// same seat and seed.
  static int _scramble(String id, int seed) {
    var hash = seed % 9999;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) % 9999;
    }
    return hash * 7919 % 9999;
  }
}
