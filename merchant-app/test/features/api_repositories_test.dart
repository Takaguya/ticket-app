// The API-backed repositories against a fake server that answers the way the
// Pin backend does (see backend/README.md), so the JSON shapes are checked.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/config/app_config.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/network/api_client.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/features/auth/domain/entities/staff_role.dart';
import 'package:merchant/features/bookings/data/datasources/bookings_api_data_source.dart';
import 'package:merchant/features/bookings/data/models/booking_json.dart';
import 'package:merchant/features/bookings/data/repositories/api_bookings_repository.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/bookings/domain/entities/check_in_result.dart';
import 'package:merchant/features/bookings/domain/repositories/bookings_repository.dart';
import 'package:merchant/features/events/data/datasources/events_api_data_source.dart';
import 'package:merchant/features/events/data/models/event_json.dart';
import 'package:merchant/features/events/data/repositories/api_events_repository.dart';
import 'package:merchant/features/events/domain/entities/event.dart';
import 'package:merchant/features/events/domain/repositories/events_repository.dart';
import 'package:merchant/features/staff/data/datasources/staff_api_data_source.dart';
import 'package:merchant/features/staff/data/repositories/api_staff_repository.dart';
import 'package:merchant/features/staff/domain/entities/team.dart';

/// Answers requests from a table of `METHOD /path` to status and JSON body.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> _answers = {};
  final Set<String> _noAnswer = {};
  final List<RequestOptions> requests = [];

  /// What each request sent as a raw (streamed) body, such as a photo.
  final Map<RequestOptions, Uint8List> sentBytes = {};

  void answer(String method, String path, Object? body, {int status = 200}) {
    _answers['$method $path'] = (status, body);
  }

  /// The next such request reaches the server but its answer is lost, as when the
  /// server stops right after saving or the connection drops.
  void loseNextAnswer(String method, String path) => _noAnswer.add('$method $path');

  List<Object?> sentAttemptIds(String path) {
    return [
      for (final request in requests)
        if (request.path == path) (request.data as Map<String, dynamic>)['attemptId'],
    ];
  }

  RequestOptions last(String method, String path) {
    return requests.lastWhere((r) => r.method == method && r.path == path);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      sentBytes[options] = Uint8List.fromList([
        for (final chunk in await requestStream.toList()) ...chunk,
      ]);
    }
    if (_noAnswer.remove('${options.method} ${options.path}')) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Connection reset',
      );
    }
    final (status, body) =
        _answers['${options.method} ${options.path}'] ??
        (404, {'code': 'not_found', 'message': 'Not Found'});
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Lets a fake request finish: Dio needs more than a few event-loop turns.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

Map<String, dynamic> bookingJson({
  String id = 'TK88900882',
  String status = 'open',
  Map<String, dynamic>? checkIn,
}) {
  return {
    'id': id,
    'eventId': 'e0',
    'buyerName': 'Bopha Keo',
    'phone': '+85549890835',
    'lines': [
      {'ticketType': '10K', 'quantity': 4},
    ],
    'totalCents': 7200,
    'payment': 'card',
    'channel': 'online',
    'status': status,
    'tshirtSizes': ['S', 'M', 'L', 'XS'],
    'checkIn': checkIn,
    'createdAt': '2026-11-12T00:00:00',
  };
}

void main() {
  late _FakeServer server;
  late Dio dio;
  late int sessionRejections;

  setUp(() {
    server = _FakeServer();
    sessionRejections = 0;
    dio = createApiClient(
      config: const AppConfig(apiBaseUrl: 'http://pin.test', useMockApi: false),
      readToken: () async => 'token-1',
      onSessionRejected: () => sessionRejections++,
    )..httpClientAdapter = server;
  });

  group('bookings', () {
    late ApiBookingsRepository repository;

    setUp(() {
      var attempts = 0;
      repository = ApiBookingsRepository(
        BookingsApiDataSource(dio),
        pollEvery: const Duration(hours: 1),
        attemptIds: () => 'attempt-${++attempts}',
      );
    });

    test('come from GET /merchant/bookings, with the access token', () async {
      server.answer('GET', '/merchant/bookings', [
        bookingJson(
          status: 'checkedIn',
          checkIn: {'at': '2026-11-12T05:12:40', 'staffName': 'Dara Keo'},
        ),
      ]);

      final bookings = await repository.watchBookings().first;

      final booking = bookings.single;
      expect(booking.id, 'TK88900882');
      expect(booking.summary, '4× 10K');
      expect(booking.payment, PaymentMethod.card);
      expect(booking.status, BookingStatus.checkedIn);
      expect(booking.tshirtSizes, ['S', 'M', 'L', 'XS']);
      expect(booking.checkIn, CheckIn(at: DateTime(2026, 11, 12, 5, 12, 40), staffName: 'Dara Keo'));
      expect(server.last('GET', '/merchant/bookings').headers['Authorization'], 'Bearer token-1');
    });

    test('a check-in shows in the watched list at once', () async {
      server
        ..answer('GET', '/merchant/bookings', [bookingJson()])
        ..answer('POST', '/merchant/checkins', {
          'result': 'admitted',
          'bookingId': 'TK88900882',
          'booking': bookingJson(
            status: 'checkedIn',
            checkIn: {'at': '2026-11-12T23:35:41', 'staffName': 'Sreyneang Lim'},
          ),
        });
      final seen = <List<Booking>>[];
      final watch = repository.watchBookings().listen(seen.add);
      await settle();

      final result = await repository.checkIn(eventId: 'e0', code: '88900882');
      await settle();

      expect(result, isA<Success<CheckInResult>>());
      expect(server.last('POST', '/merchant/checkins').data, {
        'eventId': 'e0',
        'code': '88900882',
        'attemptId': 'attempt-1',
      });
      expect(seen.last.single.status, BookingStatus.checkedIn);
      expect(seen.last.single.checkIn!.staffName, 'Sreyneang Lim');
      await watch.cancel();
    });

    test('a refusal comes back with the server message', () async {
      server.answer('POST', '/merchant/checkins', status: 409, {
        'code': 'rejected',
        'message': 'Check-in opens on the day of the event.',
      });

      final result = await repository.checkIn(eventId: 'e1', code: 'TK11111111');

      expect(
        result,
        const Result<CheckInResult>.failure(RejectedFailure('Check-in opens on the day of the event.')),
      );
    });

    test('a cancellation, a promo code and a runner are read when present', () {
      final plain = BookingJson.booking(bookingJson());
      expect(plain.cancellation, isNull);
      expect(plain.promoCode, isNull);
      expect(plain.runner, isNull);

      final booking = BookingJson.booking({
        ...bookingJson(status: 'cancelled'),
        'promoCode': 'D2D10',
        'cancellation': {
          'at': '2026-11-12T07:15:00',
          'staffName': 'Vannak Sok',
          'reason': 'eventChanged',
          'refundCents': 6480,
        },
        'runner': {
          'name': 'Sokha Chan',
          'phone': '+85510222333',
          'email': null,
          'gender': 'female',
          'age': 29,
          'nationality': 'Cambodian',
          'emergencyName': 'Dara Chan',
          'emergencyPhone': '+85510444555',
          'shirtSize': 'M',
        },
      });

      expect(booking.promoCode, 'D2D10');
      expect(booking.totalCents, 7200);
      expect(
        booking.cancellation,
        Cancellation(
          at: DateTime(2026, 11, 12, 7, 15),
          staffName: 'Vannak Sok',
          reason: CancelReason.eventChanged,
          refundCents: 6480,
        ),
      );
      expect(booking.runner!.name, 'Sokha Chan');
      expect(booking.runner!.email, isNull);
      expect(booking.runner!.age, 29);
      expect(booking.runner!.shirtSize, 'M');
    });

    test('an unknown cancellation reason reads as "other" instead of breaking the list', () {
      final booking = BookingJson.booking({
        ...bookingJson(status: 'cancelled'),
        'cancellation': {
          'at': '2026-11-12T07:15:00',
          'staffName': 'Vannak Sok',
          'reason': 'somethingNew',
          'refundCents': 7200,
        },
      });

      expect(booking.cancellation!.reason, CancelReason.other);
    });

    test('the seats of a bus trip are read; an older server sends none', () {
      final withSeats = BookingJson.booking({
        ...bookingJson(),
        'lines': [
          {'ticketType': 'Seat', 'quantity': 2},
        ],
        'seats': ['1A', '1B'],
      });

      expect(withSeats.seats, ['1A', '1B']);
      expect(BookingJson.booking(bookingJson()).seats, isEmpty);
    });

    test('the visit day of a place booking is read as a date; other bookings have none', () {
      final visit = BookingJson.booking({...bookingJson(), 'visitDate': '2026-11-28'});

      expect(visit.visitDate, DateTime(2026, 11, 28));
      expect(BookingJson.booking(bookingJson()).visitDate, isNull);
    });

    test('cancelling posts the reason and shows the cancelled booking in the list at once', () async {
      server
        ..answer('GET', '/merchant/bookings', [bookingJson()])
        ..answer('POST', '/merchant/bookings/TK88900882/cancel', {
          ...bookingJson(status: 'cancelled'),
          'cancellation': {
            'at': '2026-11-12T07:15:00',
            'staffName': 'Vannak Sok',
            'reason': 'buyerAsked',
            'refundCents': 7200,
          },
        });
      final seen = <List<Booking>>[];
      final watch = repository.watchBookings().listen(seen.add);
      await settle();

      final result = await repository.cancelBooking(
        bookingId: 'TK88900882',
        reason: CancelReason.buyerAsked,
      );
      await settle();

      expect(result, isA<Success<Booking>>());
      expect(server.last('POST', '/merchant/bookings/TK88900882/cancel').data, {'reason': 'buyerAsked'});
      expect(seen.last.single.status, BookingStatus.cancelled);
      expect(seen.last.single.cancellation!.refundCents, 7200);
      await watch.cancel();
    });

    test('a refused cancellation shows the server message as written', () async {
      server.answer('POST', '/merchant/bookings/TK88900882/cancel', status: 409, {
        'code': 'rejected',
        'message': "This booking is checked in, so it can't be cancelled.",
      });

      final result = await repository.cancelBooking(
        bookingId: 'TK88900882',
        reason: CancelReason.other,
      );

      expect(
        result,
        const Result<Booking>.failure(
          RejectedFailure("This booking is checked in, so it can't be cancelled."),
        ),
      );
    });

    test('a door sale sends the phone as +855 digits and goes first in the list', () async {
      server
        ..answer('GET', '/merchant/bookings', [bookingJson()])
        ..answer('POST', '/merchant/events/e0/door-sales', status: 201, {
          ...bookingJson(id: 'TK65325682'),
          'buyerName': 'Walk-in guest',
          'phone': '+85512345678',
          'channel': 'door',
          'payment': 'cash',
          'tshirtSizes': <String>[],
        });
      final seen = <List<Booking>>[];
      final watch = repository.watchBookings().listen(seen.add);
      await settle();

      await repository.sellAtDoor(
        const DoorSaleRequest(
          eventId: 'e0',
          lines: [BookingLine(ticketType: '10K', quantity: 2)],
          buyerPhone: '012 345 678',
          payment: PaymentMethod.cash,
        ),
      );
      await settle();

      expect(server.last('POST', '/merchant/events/e0/door-sales').data, {
        'lines': [
          {'ticketType': '10K', 'quantity': 2},
        ],
        'buyerPhone': '+85512345678',
        'payment': 'cash',
        'attemptId': 'attempt-1',
      });
      expect(seen.last.map((b) => b.id), ['TK65325682', 'TK88900882']);
      expect(seen.last.first.channel, SalesChannel.door);
      await watch.cancel();
    });

    test('a scan whose answer was lost is sent again with the same attempt ID', () async {
      server
        ..loseNextAnswer('POST', '/merchant/checkins')
        ..answer('POST', '/merchant/checkins', {
          'result': 'admitted',
          'bookingId': 'TK88900882',
          'booking': bookingJson(
            status: 'checkedIn',
            checkIn: {'at': '2026-11-13T15:02:10', 'staffName': 'Sreyneang Lim'},
          ),
        });

      final lost = await repository.checkIn(eventId: 'e0', code: '88900882');
      expect(lost, const Result<CheckInResult>.failure(NetworkFailure()));

      // The scanner tries again (typed differently, same ticket): same attempt, so the
      // server can answer "admitted" if the first try had gone through.
      final retry = await repository.checkIn(eventId: 'e0', code: 'tk88900882');
      expect(retry, isA<Success<CheckInResult>>());

      // That scan was answered; scanning the ticket again is a new scan.
      await repository.checkIn(eventId: 'e0', code: '88900882');
      expect(server.sentAttemptIds('/merchant/checkins'), ['attempt-1', 'attempt-1', 'attempt-2']);
      expect(sessionRejections, 0);
    });

    test('a server error while saving (the database went down) keeps the attempt for the retry', () async {
      const message = "Pin can't save right now. Please try again in a moment.";
      server.answer('POST', '/merchant/checkins', status: 503, {'code': 'unavailable', 'message': message});

      final failed = await repository.checkIn(eventId: 'e0', code: '88900882');
      expect(failed, const Result<CheckInResult>.failure(ServerFailure(message)));

      server.answer('POST', '/merchant/checkins', {
        'result': 'admitted',
        'bookingId': 'TK88900882',
        'booking': bookingJson(
          status: 'checkedIn',
          checkIn: {'at': '2026-11-13T15:40:00', 'staffName': 'Sreyneang Lim'},
        ),
      });
      await repository.checkIn(eventId: 'e0', code: '88900882');

      // Whether the first try was saved is unknown, so the retry is the same attempt.
      expect(server.sentAttemptIds('/merchant/checkins'), ['attempt-1', 'attempt-1']);
      expect(sessionRejections, 0);
    });

    test('a refusal from the server is an answer: the next scan is a new attempt', () async {
      server.answer('POST', '/merchant/checkins', status: 409, {
        'code': 'rejected',
        'message': 'The event has ended.',
      });

      await repository.checkIn(eventId: 'e2', code: 'TK11111111');
      await repository.checkIn(eventId: 'e2', code: 'TK11111111');

      expect(server.sentAttemptIds('/merchant/checkins'), ['attempt-1', 'attempt-2']);
    });

    test('a door sale whose answer was lost is sent again as the same sale; a changed one is new', () async {
      server
        ..loseNextAnswer('POST', '/merchant/events/e0/door-sales')
        ..answer('POST', '/merchant/events/e0/door-sales', status: 201, {
          ...bookingJson(id: 'TK65325682'),
          'channel': 'door',
          'payment': 'cash',
          'tshirtSizes': <String>[],
        });
      DoorSaleRequest sale(int tickets) => DoorSaleRequest(
        eventId: 'e0',
        lines: [BookingLine(ticketType: '10K', quantity: tickets)],
        buyerPhone: '+85512345678',
        payment: PaymentMethod.cash,
      );

      expect(await repository.sellAtDoor(sale(2)), const Result<Booking>.failure(NetworkFailure()));
      expect(await repository.sellAtDoor(sale(2)), isA<Success<Booking>>());
      await repository.sellAtDoor(sale(3));

      expect(server.sentAttemptIds('/merchant/events/e0/door-sales'), ['attempt-1', 'attempt-1', 'attempt-2']);
    });

    test('every scan answer is understood', () {
      expect(
        BookingJson.checkInResult({
          'result': 'otherEvent',
          'bookingId': 'TK11111111',
          'eventName': 'Kampot River Run 2026',
        }),
        const CheckInOtherEvent(bookingId: 'TK11111111', eventName: 'Kampot River Run 2026'),
      );
      expect(
        BookingJson.checkInResult({'result': 'notFound', 'bookingId': 'TK00000000'}),
        const CheckInNotFound('TK00000000'),
      );
      expect(
        BookingJson.checkInResult({'result': 'alreadyUsed', 'booking': bookingJson()}),
        isA<CheckInAlreadyUsed>(),
      );
    });

    test('a token the server refuses signs the app out', () async {
      server.answer('GET', '/merchant/bookings', status: 401, {
        'code': 'unauthorized',
        'message': 'Please sign in again.',
      });

      await expectLater(repository.watchBookings().first, throwsA(anything));

      expect(sessionRejections, 1);
    });
  });

  group('events', () {
    test('are read with their ticket types, and a published one shows at once', () async {
      final repository = ApiEventsRepository(EventsApiDataSource(dio), pollEvery: const Duration(hours: 1));
      server
        ..answer('GET', '/merchant/events', [
          {
            'id': 'e0',
            'name': 'Phnom Penh Half Marathon 2026',
            'startsAt': '2026-11-12T05:30:00',
            'venue': 'Riverside, Sisowath Quay',
            'kind': 'marathon',
            'commissionRate': 5.0,
            'capacity': 220,
            'ticketTypes': [
              {'name': '10K', 'priceCents': 1800, 'quantity': 80},
            ],
          },
        ])
        ..answer('POST', '/merchant/events', status: 201, {
          'id': 'e9',
          'name': 'Siem Reap Temple Run',
          'startsAt': '2026-11-28T06:00:00',
          'venue': 'Angkor Wat west gate',
          'kind': 'show',
          'commissionRate': 5.0,
          'capacity': 250,
          'ticketTypes': [
            {'name': '10K', 'priceCents': 1500, 'quantity': 150},
            {'name': '5K', 'priceCents': 0, 'quantity': 100},
          ],
        });
      final seen = <List<Event>>[];
      final watch = repository.watchEvents().listen(seen.add);
      await settle();

      expect(seen.single.single.startsAt, DateTime(2026, 11, 12, 5, 30));
      expect(seen.single.single.capacity, 80);

      await repository.publishEvent(
        EventDraft(
          name: 'Siem Reap Temple Run',
          startsAt: DateTime(2026, 11, 28, 6),
          venue: 'Angkor Wat west gate',
          kind: EventKind.show,
          ticketTypes: const [
            TicketType(name: '10K', priceCents: 1500, quantity: 150),
            TicketType(name: '5K', priceCents: 0, quantity: 100),
          ],
        ),
      );
      await settle();

      final sent = server.last('POST', '/merchant/events').data as Map<String, dynamic>;
      expect(sent['startsAt'], '2026-11-28T06:00:00');
      expect(sent['kind'], 'show');
      expect(seen.last.map((e) => e.id), ['e0', 'e9']);
      expect(seen.last.map((e) => e.kind), [EventKind.marathon, EventKind.show]);
      await watch.cancel();
    });

    test('the cover image is read as a full address, put as the raw photo and shows at once; removing clears it',
        () async {
      Map<String, dynamic> event(String? imageUrl) => {
        'id': 'e0',
        'name': 'Khmer Rock Night 2026',
        'startsAt': '2026-11-27T19:00:00',
        'venue': 'Koh Pich Theatre',
        'kind': 'concert',
        'commissionRate': 5.0,
        'capacity': 100,
        'ticketTypes': [
          {'name': 'Standard', 'priceCents': 1500, 'quantity': 100},
        ],
        'imageUrl': imageUrl,
      };
      final repository = ApiEventsRepository(EventsApiDataSource(dio), pollEvery: const Duration(hours: 1));
      server
        ..answer('GET', '/merchant/events', [event(null)])
        ..answer('PUT', '/merchant/events/e0/image', {'imageUrl': '/images/events/e0?v=1763300000000'})
        ..answer('DELETE', '/merchant/events/e0/image', null, status: 204);
      final seen = <List<Event>>[];
      final watch = repository.watchEvents().listen(seen.add);
      await settle();
      expect(seen.single.single.imageUrl, isNull);

      // The photo is the request body as it is: not JSON, and not a form.
      final photo = Uint8List.fromList([for (var i = 0; i < 300; i++) i % 256]);
      final put = await repository.setEventImage('e0', photo);
      await settle();

      expect(put, const Success<String>('http://pin.test/images/events/e0?v=1763300000000'));
      final request = server.last('PUT', '/merchant/events/e0/image');
      expect(server.sentBytes[request], photo);
      expect(request.headers['Authorization'], 'Bearer token-1');
      expect(request.headers[Headers.contentLengthHeader], 300);
      // The list shows the new picture without waiting for the next poll.
      expect(seen.last.single.imageUrl, 'http://pin.test/images/events/e0?v=1763300000000');

      expect(await repository.removeEventImage('e0'), isA<Success<void>>());
      await settle();
      expect(seen.last.single.imageUrl, isNull);

      // An address the server already sends in full, or an event that has one, is read as it is.
      server.answer('GET', '/merchant/events', [event('/images/events/e0?v=7')]);
      await repository.watchEvents().first;
      await watch.cancel();
      final fresh = ApiEventsRepository(EventsApiDataSource(dio), pollEvery: const Duration(hours: 1));
      expect((await fresh.watchEvents().first).single.imageUrl, 'http://pin.test/images/events/e0?v=7');
    });

    test('a refused photo comes back with the server message and changes nothing', () async {
      final repository = ApiEventsRepository(EventsApiDataSource(dio), pollEvery: const Duration(hours: 1));
      server.answer(
        'PUT',
        '/merchant/events/e0/image',
        {'code': 'rejected', 'message': 'That file is not a picture. Choose a JPEG or PNG image.'},
        status: 400,
      );

      final result = await repository.setEventImage('e0', Uint8List.fromList([1, 2, 3]));

      expect(
        result,
        const FailureResult<String>(RejectedFailure('That file is not a picture. Choose a JPEG or PNG image.')),
      );
    });

    test('a bus trip is posted to /merchant/events/bus-trips and read with its bus details', () async {
      final repository = ApiEventsRepository(EventsApiDataSource(dio), pollEvery: const Duration(hours: 1));
      server
        ..answer('GET', '/merchant/events', <Object?>[])
        ..answer('POST', '/merchant/events/bus-trips', status: 201, {
          'id': 'e7',
          'name': 'Phnom Penh to Kampot',
          'startsAt': '2026-11-20T08:00:00',
          'venue': 'Giant Ibis Terminal',
          'kind': 'bus',
          'commissionRate': 5.0,
          'capacity': 30,
          'approved': false,
          'ticketTypes': [
            {'name': 'Seat', 'priceCents': 1600, 'quantity': 30},
          ],
          'bus': {
            'origin': 'Phnom Penh',
            'destination': 'Kampot',
            'durationMinutes': 210,
            'coachType': 'vip',
            'coachLabel': 'VIP seater · 2+1',
            'seats': 30,
            'amenities': ['A/C', 'Wi-Fi'],
          },
        });
      final seen = <List<Event>>[];
      final watch = repository.watchEvents().listen(seen.add);
      await settle();

      final result = await repository.publishBusTrip(
        TripDraft(
          origin: 'Phnom Penh',
          destination: 'Kampot',
          startsAt: DateTime(2026, 11, 20, 8),
          durationMinutes: 210,
          coach: CoachType.vip,
          priceCents: 1600,
          boardingPoint: 'Giant Ibis Terminal',
          amenities: const ['A/C', 'Wi-Fi'],
        ),
      );
      await settle();

      // Optional texts that were left empty are not sent.
      expect(server.last('POST', '/merchant/events/bus-trips').data, {
        'origin': 'Phnom Penh',
        'destination': 'Kampot',
        'startsAt': '2026-11-20T08:00:00',
        'durationMinutes': 210,
        'coachType': 'vip',
        'priceCents': 1600,
        'boardingPoint': 'Giant Ibis Terminal',
        'amenities': ['A/C', 'Wi-Fi'],
      });
      final trip = result.when(success: (event) => event, failure: (_) => throw StateError('refused'));
      expect(trip.kind, EventKind.bus);
      expect(trip.approved, isFalse);
      expect(trip.bus?.coach, CoachType.vip);
      expect(trip.bus?.durationMinutes, 210);
      expect(trip.bus?.amenities, ['A/C', 'Wi-Fi']);
      expect(seen.last.single.id, 'e7');
      await watch.cancel();
    });

    test('a screening is posted to /merchant/events/screenings and read with its film details', () async {
      final repository = ApiEventsRepository(EventsApiDataSource(dio), pollEvery: const Duration(hours: 1));
      server
        ..answer('GET', '/merchant/events', <Object?>[])
        ..answer('POST', '/merchant/events/screenings', status: 201, {
          'id': 'e12',
          'name': 'Skyline Run',
          'startsAt': '2026-11-20T19:00:00',
          'venue': 'Legend Cinema, Aeon Mall',
          'kind': 'cinema',
          'commissionRate': 5.0,
          'capacity': 120,
          'approved': false,
          'ticketTypes': [
            {'name': 'Seat', 'priceCents': 700, 'quantity': 120},
          ],
          'screening': {
            'filmTitle': 'Skyline Run',
            'rating': 'PG-13',
            'genre': 'Action',
            'runtimeMinutes': 128,
            'hall': 'Hall 2',
            'hallSize': 'large',
            'hallLabel': 'Large hall · 120 seats',
            'seats': 120,
          },
        });
      final seen = <List<Event>>[];
      final watch = repository.watchEvents().listen(seen.add);
      await settle();

      final result = await repository.publishScreening(
        ScreeningDraft(
          filmTitle: 'Skyline Run',
          runtimeMinutes: 128,
          theatre: 'Legend Cinema, Aeon Mall',
          hall: 'Hall 2',
          hallSize: HallSize.large,
          startsAt: DateTime(2026, 11, 20, 19),
          priceCents: 700,
          rating: 'PG-13',
        ),
      );
      await settle();

      // Optional texts that were left empty are not sent.
      expect(server.last('POST', '/merchant/events/screenings').data, {
        'filmTitle': 'Skyline Run',
        'runtimeMinutes': 128,
        'theatre': 'Legend Cinema, Aeon Mall',
        'hall': 'Hall 2',
        'hallSize': 'large',
        'startsAt': '2026-11-20T19:00:00',
        'priceCents': 700,
        'rating': 'PG-13',
      });
      final event = result.when(success: (event) => event, failure: (_) => throw StateError('refused'));
      expect(event.kind, EventKind.cinema);
      expect(event.approved, isFalse);
      expect(event.screening?.filmTitle, 'Skyline Run');
      expect(event.screening?.hallSize, HallSize.large);
      expect(event.screening?.rating, 'PG-13');
      expect(event.screening?.genre, 'Action');
      expect(seen.last.single.id, 'e12');
      await watch.cancel();
    });

    test('a place is posted to /merchant/events/places and read as a place with limits per day', () async {
      final repository = ApiEventsRepository(EventsApiDataSource(dio), pollEvery: const Duration(hours: 1));
      server
        ..answer('GET', '/merchant/events', <Object?>[])
        ..answer('POST', '/merchant/events/places', status: 201, {
          'id': 'e14',
          'name': 'Garden City Water Park',
          'startsAt': '2026-11-16T00:00:00',
          'venue': 'Garden City',
          'kind': 'admission',
          'commissionRate': 5.0,
          'capacity': 100300,
          'approved': false,
          'ticketTypes': [
            {'name': 'Adult', 'priceCents': 1000, 'quantity': 300},
            {'name': 'Child', 'priceCents': 600, 'quantity': 100000},
          ],
        });
      final seen = <List<Event>>[];
      final watch = repository.watchEvents().listen(seen.add);
      await settle();

      final result = await repository.publishPlace(
        const PlaceDraft(
          name: 'Garden City Water Park',
          venue: 'Garden City',
          policy: 'Refundable up to the day before',
          tickets: [
            PlaceTicketDraft(name: 'Adult', priceCents: 1000, dailyLimit: 300),
            PlaceTicketDraft(name: 'Child', priceCents: 600, description: 'Under 12'),
          ],
        ),
      );
      await settle();

      // Optional texts that were left empty, and a missing limit, are not sent.
      expect(server.last('POST', '/merchant/events/places').data, {
        'name': 'Garden City Water Park',
        'venue': 'Garden City',
        'policy': 'Refundable up to the day before',
        'ticketTypes': [
          {'name': 'Adult', 'priceCents': 1000, 'dailyLimit': 300},
          {'name': 'Child', 'priceCents': 600, 'description': 'Under 12'},
        ],
      });
      final place = result.when(success: (event) => event, failure: (_) => throw StateError('refused'));
      expect(place.kind, EventKind.admission);
      expect(place.isPlace, isTrue);
      expect(place.approved, isFalse);
      expect(place.ticketTypes.map((t) => t.hasLimit), [true, false]);
      expect(place.ticketTypes.first.quantity, 300);
      expect(seen.last.single.id, 'e14');
      await watch.cancel();
    });

    test('a hall size this app does not know reads as standard instead of breaking the list', () {
      final event = EventJson.event({
        'id': 'e13',
        'name': 'Odd Film',
        'startsAt': '2026-11-20T19:00:00',
        'venue': 'Somewhere',
        'kind': 'cinema',
        'commissionRate': 5.0,
        'ticketTypes': <Object?>[],
        'screening': {'filmTitle': 'Odd Film', 'runtimeMinutes': 90, 'hall': 'Hall 1', 'hallSize': 'imax'},
      });

      expect(event.screening?.hallSize, HallSize.standard);
    });

    test('a coach this app does not know reads as a seater instead of breaking the list', () {
      final event = EventJson.event({
        'id': 'e8',
        'name': 'Future Trip',
        'startsAt': '2026-11-20T08:00:00',
        'venue': 'Somewhere',
        'kind': 'bus',
        'commissionRate': 5.0,
        'ticketTypes': [
          {'name': 'Seat', 'priceCents': 0, 'quantity': 10},
        ],
        'bus': {'origin': 'A', 'destination': 'B', 'durationMinutes': 60, 'coachType': 'hoverbus'},
      });

      expect(event.bus?.coach, CoachType.seater);
      expect(event.bus?.amenities, isEmpty);
    });
  });

  group('staff', () {
    test('the team, removing a scanner and a new join code', () async {
      final repository = ApiStaffRepository(StaffApiDataSource(dio), pollEvery: const Duration(hours: 1));
      server
        ..answer('GET', '/merchant/staff', {
          'joinCode': '482913',
          'members': [
            {'id': 'u1', 'name': 'Vannak Sok', 'role': 'owner'},
            {'id': 'u2', 'name': 'Dara Keo', 'role': 'scanner'},
          ],
        })
        ..answer('DELETE', '/merchant/staff/u2', null, status: 204)
        ..answer('POST', '/merchant/staff/join-code', {'joinCode': '617508'});
      final seen = <Team>[];
      final watch = repository.watchTeam().listen(seen.add);
      await settle();
      expect(seen.single.members.map((m) => m.role), [StaffRole.owner, StaffRole.scanner]);

      expect(await repository.removeMember('u2'), isA<Success<void>>());
      expect(await repository.regenerateJoinCode(), const Result<String>.success('617508'));
      await settle();

      expect(seen.last.members.map((m) => m.name), ['Vannak Sok']);
      expect(seen.last.joinCode, '617508');
      await watch.cancel();
    });
  });
}
