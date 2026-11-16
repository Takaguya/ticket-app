import 'dart:async';
import 'dart:math' as math;

import '../core/error/exceptions.dart';
import '../features/auth/domain/entities/staff_role.dart';
import '../features/bookings/domain/entities/booking.dart';
import '../features/bookings/domain/entities/check_in_result.dart';
import '../features/bookings/domain/repositories/bookings_repository.dart';
import '../features/events/domain/entities/event.dart';
import '../features/events/domain/repositories/events_repository.dart';
import '../features/staff/domain/entities/team.dart';

/// An in-memory stand-in for the Pin server, used until the backend exists.
///
/// It keeps events, bookings and staff per business and applies the business
/// rules from the developer handoff (check-in results, capacity, roles), so
/// it also documents what the real server has to do. Nothing is saved:
/// everything resets when the app restarts.
///
/// The demo business ([demoBusinessId]) is seeded with sample data. A newly
/// registered business starts empty.
class MockMerchantBackend {
  MockMerchantBackend({
    this.latency = const Duration(milliseconds: 350),
    this._clock = DateTime.now,
    math.Random? random,
  }) : _random = random ?? math.Random();

  static const demoBusinessId = 'b_1';
  static const demoJoinCode = '482913';

  /// A real ticket for someone else's event, to demonstrate that answer.
  static const foreignTicketId = 'TK70455218';

  /// Simulated network delay.
  final Duration latency;
  final DateTime Function() _clock;
  final math.Random _random;
  final Map<String, _Business> _businesses = {};
  int _sequence = 1000;

  // ---------------------------------------------------------------- accounts

  /// Creates the records of a newly registered business.
  void registerBusiness({
    required String businessId,
    required String ownerId,
    required String ownerName,
  }) {
    _businesses[businessId] = _Business(
      staff: [StaffMember(id: ownerId, name: ownerName, role: StaffRole.owner)],
      joinCode: _newJoinCode(),
    );
  }

  /// The business a join code belongs to, or null when no business uses it.
  String? businessIdForJoinCode(String code) {
    _business(demoBusinessId);
    final digits = code.replaceAll(RegExp(r'\D'), '');
    for (final entry in _businesses.entries) {
      if (entry.value.joinCode == digits) return entry.key;
    }
    return null;
  }

  void addScanner({required String businessId, required String memberId, required String name}) {
    final business = _business(businessId);
    business.staff.add(StaffMember(id: memberId, name: name, role: StaffRole.scanner));
    business.publishTeam();
  }

  // ------------------------------------------------------------------ events

  Stream<List<Event>> watchEvents(String businessId) {
    final business = _business(businessId);
    return _currentThenChanges(business.eventChanges, () => List.unmodifiable(business.events));
  }

  Future<Event> publishEvent(String businessId, EventDraft draft) async {
    await Future<void>.delayed(latency);
    final kind = draft.kind;
    if (kind == null) {
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: 'Choose what kind of event it is.',
        statusCode: 400,
      );
    }
    final business = _business(businessId);
    final event = Event(
      id: 'e${_sequence++}',
      name: draft.name,
      kind: kind,
      startsAt: draft.startsAt,
      venue: draft.venue,
      ticketTypes: draft.ticketTypes,
    );
    business.events.add(event);
    business.publishEvents();
    return event;
  }

  /// Publishes a bus trip as the server does: named after its route, boarding
  /// at the venue, with one ticket type, "Seat", and as many seats for sale as
  /// the coach has.
  Future<Event> publishBusTrip(String businessId, TripDraft draft) async {
    await Future<void>.delayed(latency);
    void refuse(String message) =>
        throw ApiException(code: ApiErrorCodes.rejected, message: message, statusCode: 400);

    final origin = draft.origin.trim();
    final destination = draft.destination.trim();
    if (origin.isEmpty) refuse('Enter where the trip starts.');
    if (destination.isEmpty) refuse('Enter where the trip goes.');
    if (origin.toLowerCase() == destination.toLowerCase()) {
      refuse('The trip must go somewhere other than where it starts.');
    }
    if (draft.durationMinutes < 10 || draft.durationMinutes > 24 * 60) {
      refuse('The trip takes between 10 minutes and 24 hours.');
    }
    if (draft.boardingPoint.trim().isEmpty) refuse('Enter the venue.');
    final today = DateTime(_clock().year, _clock().month, _clock().day);
    if (draft.startsAt.isBefore(today)) refuse('The event date cannot be in the past.');

    final business = _business(businessId);
    final event = Event(
      id: 'e${_sequence++}',
      name: '$origin to $destination',
      kind: EventKind.bus,
      bus: BusDetails(
        origin: origin,
        destination: destination,
        durationMinutes: draft.durationMinutes,
        coach: draft.coach,
        amenities: draft.amenities,
      ),
      startsAt: draft.startsAt,
      venue: draft.boardingPoint.trim(),
      ticketTypes: [
        TicketType(name: 'Seat', priceCents: draft.priceCents, quantity: draft.coach.seats),
      ],
    );
    business.events.add(event);
    business.publishEvents();
    return event;
  }

  /// Publishes a place as the server does: open every day, so its date is the
  /// day it was published, and each ticket type's quantity is its limit per
  /// day (no limit when left out).
  Future<Event> publishPlace(String businessId, PlaceDraft draft) async {
    await Future<void>.delayed(latency);
    void refuse(String message) =>
        throw ApiException(code: ApiErrorCodes.rejected, message: message, statusCode: 400);

    final name = draft.name.trim();
    if (name.length < 3) refuse('Give the event a name of at least 3 characters.');
    if (draft.venue.trim().isEmpty) refuse('Enter the venue.');
    if (draft.tickets.isEmpty) refuse('Add at least one ticket type.');
    if (draft.tickets.length > 6) refuse('An event can have at most 6 ticket types.');
    for (final ticket in draft.tickets) {
      if (ticket.name.trim().isEmpty) refuse('Give every ticket type a name.');
      final limit = ticket.dailyLimit;
      if (limit != null && limit < 1) {
        refuse('A daily limit is at least 1. Leave it empty for no limit.');
      }
    }

    final business = _business(businessId);
    final now = _clock();
    final event = Event(
      id: 'e${_sequence++}',
      name: name,
      kind: EventKind.admission,
      startsAt: DateTime(now.year, now.month, now.day),
      venue: draft.venue.trim(),
      ticketTypes: [
        for (final ticket in draft.tickets)
          TicketType(
            name: ticket.name.trim(),
            priceCents: ticket.priceCents,
            quantity: ticket.dailyLimit ?? TicketType.noLimit,
          ),
      ],
    );
    business.events.add(event);
    business.publishEvents();
    return event;
  }

  /// Publishes a cinema screening as the server does: named after the film,
  /// shown at the cinema, with one ticket type, "Seat", and as many seats for
  /// sale as the hall has.
  Future<Event> publishScreening(String businessId, ScreeningDraft draft) async {
    await Future<void>.delayed(latency);
    void refuse(String message) =>
        throw ApiException(code: ApiErrorCodes.rejected, message: message, statusCode: 400);

    final title = draft.filmTitle.trim();
    if (title.isEmpty) refuse("Enter the film's title.");
    if (draft.runtimeMinutes < 10 || draft.runtimeMinutes > 10 * 60) {
      refuse('The film runs between 10 minutes and 10 hours.');
    }
    if (draft.hall.trim().isEmpty) refuse('Enter the hall, e.g. Hall 3.');
    if (draft.theatre.trim().isEmpty) refuse('Enter the cinema.');
    final today = DateTime(_clock().year, _clock().month, _clock().day);
    if (draft.startsAt.isBefore(today)) refuse('The event date cannot be in the past.');

    final business = _business(businessId);
    final event = Event(
      id: 'e${_sequence++}',
      name: title,
      kind: EventKind.cinema,
      screening: ScreeningDetails(
        filmTitle: title,
        runtimeMinutes: draft.runtimeMinutes,
        hall: draft.hall.trim(),
        hallSize: draft.hallSize,
        rating: draft.rating.trim(),
        genre: draft.genre.trim(),
      ),
      startsAt: draft.startsAt,
      venue: draft.theatre.trim(),
      ticketTypes: [
        TicketType(name: 'Seat', priceCents: draft.priceCents, quantity: draft.hallSize.seats),
      ],
    );
    business.events.add(event);
    business.publishEvents();
    return event;
  }

  // ---------------------------------------------------------------- bookings

  Stream<List<Booking>> watchBookings(String businessId) {
    final business = _business(businessId);
    return _currentThenChanges(
      business.bookingChanges,
      () => List.unmodifiable(business.bookings),
    );
  }

  /// Decides a scan in one step: nothing else can change the booking between
  /// reading its status and marking it checked in.
  Future<CheckInResult> checkIn({
    required String businessId,
    required String eventId,
    required String code,
    required String staffName,
  }) async {
    await Future<void>.delayed(latency);
    final business = _business(businessId);
    final id = normalizeBookingId(code);

    if (id == foreignTicketId) {
      return const CheckInOtherEvent(
        bookingId: foreignTicketId,
        eventName: 'Laugh PP: Stand-up Comedy Night',
        buyerName: 'Bopha Meas',
        summary: '2× Standard seat',
      );
    }

    final index = business.bookings.indexWhere((b) => b.id == id);
    if (index < 0) return CheckInNotFound(id);

    final booking = business.bookings[index];
    if (booking.eventId != eventId) {
      return CheckInOtherEvent(
        bookingId: id,
        eventName: business.eventById(booking.eventId)?.name ?? 'another event',
        buyerName: booking.buyerName,
        summary: booking.summary,
      );
    }

    final event = business.eventById(eventId);
    if (event == null) return CheckInNotFound(id);
    switch (event.timingOn(_clock())) {
      case EventTiming.upcoming:
        throw const ApiException(
          code: ApiErrorCodes.rejected,
          message: 'Check-in opens on the day of the event.',
          statusCode: 409,
        );
      case EventTiming.past:
        throw const ApiException(
          code: ApiErrorCodes.rejected,
          message: 'The event has ended.',
          statusCode: 409,
        );
      case EventTiming.today:
        break;
    }

    switch (booking.status) {
      case BookingStatus.cancelled:
        return CheckInCancelled(booking);
      case BookingStatus.checkedIn:
        return CheckInAlreadyUsed(booking);
      case BookingStatus.open:
        final admitted = _copy(
          booking,
          status: BookingStatus.checkedIn,
          checkIn: CheckIn(at: _clock(), staffName: staffName),
        );
        business.bookings[index] = admitted;
        business.publishBookings();
        return CheckInAdmitted(admitted);
    }
  }

  Future<Booking> sellAtDoor(String businessId, DoorSaleRequest request) async {
    await Future<void>.delayed(latency);
    final business = _business(businessId);
    final event = business.eventById(request.eventId);
    if (event == null) {
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: 'This event no longer exists.',
        statusCode: 404,
      );
    }

    // A place's tickets sold at the door are for today, and today's limits apply.
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final counted = business.bookings.where(
      (b) =>
          b.eventId == event.id &&
          b.countsAsSold &&
          (!event.isPlace || _sameDay(b.visitDate, today)),
    );
    final count = request.lines.fold(0, (sum, line) => sum + line.quantity);
    final sold = counted.fold(0, (sum, b) => sum + b.ticketCount);
    final left = math.max(0, event.capacity - sold);
    if (count <= 0 || count > left) {
      throw ApiException(
        code: ApiErrorCodes.rejected,
        message: left == 0 ? 'Sold out. No tickets left to sell.' : 'Only $left left',
        statusCode: 409,
      );
    }
    if (event.isPlace) {
      for (final line in request.lines) {
        final type = event.ticketTypes.where((t) => t.name == line.ticketType).firstOrNull;
        if (type == null || !type.hasLimit) continue;
        final typeLeft = math.max(
          0,
          type.quantity - counted.fold(0, (sum, b) => sum + b.quantityOf(type.name)),
        );
        if (line.quantity > typeLeft) {
          throw ApiException(
            code: ApiErrorCodes.rejected,
            message: typeLeft == 0
                ? '${type.name} is sold out.'
                : 'Only $typeLeft left for ${type.name}.',
            statusCode: 409,
          );
        }
      }
    }

    // A door sale of a bus trip or a screening takes the next free seats, front row first.
    final allSeats = event.bus?.coach.seatIds ?? event.screening?.hallSize.seatIds;
    final heldSeats = {
      for (final b in business.bookings)
        if (b.eventId == event.id && b.countsAsSold) ...b.seats,
    };
    final seats = allSeats == null
        ? const <String>[]
        : [...allSeats.where((seat) => !heldSeats.contains(seat)).take(count)];

    final prices = {for (final type in event.ticketTypes) type.name: type.priceCents};
    final booking = Booking(
      id: _newBookingId(business),
      eventId: event.id,
      buyerName: 'Walk-in guest',
      phone: request.buyerPhone,
      lines: request.lines,
      totalCents: request.lines.fold(
        0,
        (sum, line) => sum + (prices[line.ticketType] ?? 0) * line.quantity,
      ),
      payment: request.payment,
      channel: SalesChannel.door,
      status: BookingStatus.open,
      seats: seats,
      visitDate: event.isPlace ? today : null,
    );
    business.bookings.insert(0, booking);
    business.publishBookings();
    return booking;
  }

  /// The owner cancels a whole booking, as the server does: a cancelled booking
  /// is answered unchanged (the first reason stays); otherwise it is refused
  /// once the event's day has passed or the booking is checked in. An online
  /// booking is refunded in full by Pin; a door sale is paid back by the
  /// business itself, so its refund is 0.
  Future<Booking> cancelBooking({
    required String businessId,
    required String bookingId,
    required CancelReason reason,
    required String staffName,
  }) async {
    await Future<void>.delayed(latency);
    final business = _business(businessId);
    final index = business.bookings.indexWhere((b) => b.id == normalizeBookingId(bookingId));
    final booking = index < 0 ? null : business.bookings[index];
    final event = booking == null ? null : business.eventById(booking.eventId);
    if (booking == null || event == null) {
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: 'This booking does not exist.',
        statusCode: 404,
      );
    }

    if (booking.status == BookingStatus.cancelled) return booking;
    if (event.timingOn(_clock()) == EventTiming.past) {
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: 'The event has ended.',
        statusCode: 409,
      );
    }
    if (booking.status == BookingStatus.checkedIn) {
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: "This booking is checked in, so it can't be cancelled.",
        statusCode: 409,
      );
    }

    final cancelled = _copy(
      booking,
      status: BookingStatus.cancelled,
      cancellation: Cancellation(
        at: _clock(),
        staffName: staffName,
        reason: reason,
        refundCents: booking.channel == SalesChannel.online ? booking.totalCents : 0,
      ),
    );
    business.bookings[index] = cancelled;
    business.publishBookings();
    return cancelled;
  }

  // ------------------------------------------------------------------- staff

  Stream<Team> watchTeam(String businessId) {
    final business = _business(businessId);
    return _currentThenChanges(business.teamChanges, business.team);
  }

  Future<void> removeMember(String businessId, String memberId) async {
    await Future<void>.delayed(latency);
    final business = _business(businessId);
    final isOwner = business.staff.any((m) => m.id == memberId && m.role == StaffRole.owner);
    if (isOwner) {
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: 'The owner cannot be removed.',
        statusCode: 409,
      );
    }
    business.staff.removeWhere((m) => m.id == memberId);
    business.publishTeam();
  }

  Future<String> regenerateJoinCode(String businessId) async {
    await Future<void>.delayed(latency);
    final business = _business(businessId)..joinCode = _newJoinCode();
    business.publishTeam();
    return business.joinCode;
  }

  // ----------------------------------------------------------------- helpers

  /// `48213377` and `tk48213377` both become `TK48213377`.
  static String normalizeBookingId(String code) {
    final trimmed = code.trim().toUpperCase();
    return RegExp(r'^\d+$').hasMatch(trimmed) ? 'TK$trimmed' : trimmed;
  }

  _Business _business(String businessId) {
    return _businesses.putIfAbsent(
      businessId,
      () => businessId == demoBusinessId
          ? _seedDemoBusiness(_clock())
          : _Business(staff: [], joinCode: _newJoinCode()),
    );
  }

  String _newJoinCode() => (100000 + _random.nextInt(900000)).toString();

  String _newBookingId(_Business business) {
    while (true) {
      final id = 'TK${10000000 + _random.nextInt(89999999)}';
      if (business.bookings.every((b) => b.id != id)) return id;
    }
  }

  /// The value right now, followed by every later value.
  Stream<T> _currentThenChanges<T>(Stream<T> changes, T Function() current) async* {
    yield current();
    yield* changes;
  }
}

Booking _copy(
  Booking booking, {
  required BookingStatus status,
  CheckIn? checkIn,
  Cancellation? cancellation,
}) {
  return Booking(
    id: booking.id,
    eventId: booking.eventId,
    buyerName: booking.buyerName,
    phone: booking.phone,
    lines: booking.lines,
    totalCents: booking.totalCents,
    payment: booking.payment,
    channel: booking.channel,
    status: status,
    promoCode: booking.promoCode,
    tshirtSizes: booking.tshirtSizes,
    checkIn: checkIn,
    cancellation: cancellation,
    runner: booking.runner,
    seats: booking.seats,
    visitDate: booking.visitDate,
  );
}

bool _sameDay(DateTime? a, DateTime b) {
  return a != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

/// One business's records and the streams that announce changes to them.
class _Business {
  // Copies every list so the seed data, which may be constant, can change.
  _Business({
    required List<StaffMember> staff,
    required this.joinCode,
    List<Event>? events,
    List<Booking>? bookings,
  }) : staff = [...staff],
       events = [...?events],
       bookings = [...?bookings];

  final List<Event> events;
  final List<Booking> bookings;
  final List<StaffMember> staff;
  String joinCode;

  final _eventChanges = StreamController<List<Event>>.broadcast();
  final _bookingChanges = StreamController<List<Booking>>.broadcast();
  final _teamChanges = StreamController<Team>.broadcast();

  Stream<List<Event>> get eventChanges => _eventChanges.stream;
  Stream<List<Booking>> get bookingChanges => _bookingChanges.stream;
  Stream<Team> get teamChanges => _teamChanges.stream;

  Team team() => Team(members: List.unmodifiable(staff), joinCode: joinCode);

  Event? eventById(String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  void publishEvents() => _eventChanges.add(List.unmodifiable(events));
  void publishBookings() => _bookingChanges.add(List.unmodifiable(bookings));
  void publishTeam() => _teamChanges.add(team());
}

// ------------------------------------------------------------------ seed data

_Business _seedDemoBusiness(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int dayOffset, int hour, int minute) {
    return DateTime(today.year, today.month, today.day + dayOffset, hour, minute);
  }

  const marathonTypes = [
    TicketType(name: '5K Fun run', priceCents: 1200, quantity: 100),
    TicketType(name: '10K', priceCents: 1800, quantity: 80),
    TicketType(name: '21K Half marathon', priceCents: 2500, quantity: 40),
  ];
  const kampotTypes = [
    TicketType(name: '5K', priceCents: 1000, quantity: 150),
    TicketType(name: '10K', priceCents: 1500, quantity: 150),
    TicketType(name: '21K Half marathon', priceCents: 2200, quantity: 150),
  ];
  const nightRunTypes = [
    TicketType(name: '3K Family run', priceCents: 800, quantity: 120),
    TicketType(name: '5K', priceCents: 1200, quantity: 120),
    TicketType(name: '10K', priceCents: 1800, quantity: 120),
  ];

  final marathon = Event(
    id: 'e0',
    name: 'Phnom Penh Half Marathon 2026',
    kind: EventKind.marathon,
    startsAt: at(0, 5, 30),
    venue: 'Riverside, Sisowath Quay',
    ticketTypes: marathonTypes,
  );
  final kampot = Event(
    id: 'e1',
    name: 'Kampot River Run 2026',
    kind: EventKind.marathon,
    startsAt: at(8, 6, 0),
    venue: 'Old Bridge, Kampot',
    ticketTypes: kampotTypes,
  );
  final nightRun = Event(
    id: 'e2',
    name: 'Riverside Night Run 2026',
    kind: EventKind.marathon,
    startsAt: at(-21, 18, 30),
    venue: 'Riverside, Sisowath Quay',
    ticketTypes: nightRunTypes,
  );

  return _Business(
    events: [marathon, kampot, nightRun],
    bookings: [
      // Today's event: most guests have arrived since 04:30.
      ..._seedBookings(marathon, count: 64, seed: 20261018, firstCheckIn: at(0, 4, 30)),
      // Next week: sold, nobody checked in.
      ..._seedBookings(kampot, count: 110, seed: 77123, withSizes: false),
      // Three weeks ago: finished.
      ..._seedBookings(nightRun, count: 90, seed: 51877, firstCheckIn: at(-21, 17, 30)),
    ],
    staff: const [
      StaffMember(id: 'u_1', name: 'Vannak Sok', role: StaffRole.owner),
      StaffMember(id: 'u_2', name: 'Dara Keo', role: StaffRole.scanner),
      StaffMember(id: 'u_3', name: 'Sreyneang Lim', role: StaffRole.scanner),
    ],
    joinCode: MockMerchantBackend.demoJoinCode,
  );
}

const _firstNames = [
  'Sokha', 'Dara', 'Bopha', 'Chanthy', 'Vichea', 'Sreymom', 'Rithy', 'Kunthea',
  'Piseth', 'Sophea', 'Makara', 'Leakhena', 'Visal', 'Chenda', 'Narith', 'Malis', //
];
const _lastNames = [
  'Chan', 'Keo', 'Sok', 'Meas', 'Lim', 'Heng', 'Chea', 'Ouk', 'Pich', 'Ros', 'Seng', 'Tep', //
];
const _sizes = ['XS', 'S', 'M', 'M', 'L', 'L', 'XL'];

/// Sample bookings for [event]. The same [seed] always gives the same list.
/// When [firstCheckIn] is set, about two thirds are already checked in, a
/// little later each time.
List<Booking> _seedBookings(
  Event event, {
  required int count,
  required int seed,
  DateTime? firstCheckIn,
  bool withSizes = true,
}) {
  final random = _Xorshift(seed);
  final types = event.ticketTypes;
  final ids = <String>{};
  final bookings = <Booking>[];
  var minutes = 2;

  for (var i = 0; i < count; i++) {
    final pick = random.next();
    final type = types[pick < 0.45 ? 0 : (pick < 0.78 ? 1 : 2)];
    final quantity = 1 + random.below(identical(type, types[2]) ? 2 : 4);
    final fate = random.next();

    var id = 'TK${10000000 + random.below(89999999)}';
    while (!ids.add(id)) {
      id = 'TK${10000000 + random.below(89999999)}';
    }

    final status = fate < 0.06
        ? BookingStatus.cancelled
        : (firstCheckIn != null && fate < 0.68 ? BookingStatus.checkedIn : BookingStatus.open);
    CheckIn? checkIn;
    if (status == BookingStatus.checkedIn) {
      minutes += (random.next() * 2.6).floor();
      checkIn = CheckIn(
        at: firstCheckIn!.add(Duration(minutes: minutes)),
        staffName: random.next() < 0.55 ? 'Dara Keo' : 'Sreyneang Lim',
      );
    }

    bookings.add(
      Booking(
        id: id,
        eventId: event.id,
        buyerName:
            '${_firstNames[random.below(_firstNames.length)]} '
            '${_lastNames[random.below(_lastNames.length)]}',
        phone: '0${10 + random.below(89)} ${100 + random.below(900)} ${100 + random.below(900)}',
        lines: [BookingLine(ticketType: type.name, quantity: quantity)],
        tshirtSizes: withSizes
            ? [for (var n = 0; n < quantity; n++) _sizes[random.below(_sizes.length)]]
            : const [],
        totalCents: quantity * type.priceCents,
        payment: random.next() < 0.6 ? PaymentMethod.abaKhqr : PaymentMethod.card,
        channel: SalesChannel.online,
        status: status,
        checkIn: checkIn,
      ),
    );
  }
  return bookings;
}

/// Small repeatable random number generator for the sample data.
class _Xorshift {
  _Xorshift(this._state);

  int _state;

  /// A number from 0 (inclusive) to 1 (exclusive).
  double next() {
    _state = (_state ^ (_state << 13)) & 0xFFFFFFFF;
    _state ^= _state >> 17;
    _state = (_state ^ (_state << 5)) & 0xFFFFFFFF;
    return _state / 4294967296;
  }

  int below(int limit) => (next() * limit).floor();
}
