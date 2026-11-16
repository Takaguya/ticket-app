// The API-backed data sources and repositories against a fake server that
// answers the way the Pin backend does (see backend/README.md), so the JSON
// shapes are checked.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/config/app_config.dart';
import 'package:user/core/error/exceptions.dart';
import 'package:user/core/error/failure.dart';
import 'package:user/core/network/api_client.dart';
import 'package:user/core/result/result.dart';
import 'package:user/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:user/features/auth/domain/entities/gender.dart';
import 'package:user/features/auth/domain/entities/otp_verification.dart';
import 'package:user/features/booking/data/datasources/booking_api_data_source.dart';
import 'package:user/features/booking/data/models/booking_json.dart';
import 'package:user/features/booking/data/repositories/api_booking_repository.dart';
import 'package:user/features/booking/domain/entities/booking.dart';
import 'package:user/features/booking/domain/entities/booking_cancellation.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/domain/entities/order.dart';
import 'package:user/features/booking/domain/entities/runner_details.dart';
import 'package:user/features/booking/domain/entities/seat_map.dart';
import 'package:user/features/booking/domain/entities/snack.dart';
import 'package:user/features/catalog/data/datasources/catalog_api_data_source.dart';
import 'package:user/features/catalog/data/repositories/api_catalog_repository.dart';
import 'package:user/features/catalog/domain/entities/bus_departure.dart';
import 'package:user/features/catalog/domain/entities/event_kind.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/features/catalog/domain/entities/place_availability.dart';
import 'package:user/features/catalog/domain/entities/showtime.dart';
import 'package:user/features/catalog/domain/entities/ticket_category.dart';

/// Answers requests from a table of `METHOD /path` to status and JSON body.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> _answers = {};
  final List<RequestOptions> requests = [];

  void answer(String method, String path, Object? body, {int status = 200}) {
    _answers['$method $path'] = (status, body);
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

Map<String, dynamic> eventJson({String id = 'e1', String name = 'Phnom Penh Half Marathon'}) {
  return {
    'id': id,
    'name': name,
    'startsAt': '2026-12-06T05:30:00',
    'venue': 'Olympic Stadium',
    'venueDetail': 'Phnom Penh',
    'about': 'A flat, fast course.',
    'organiser': 'PP Runners',
    'policy': 'No refunds',
    'kind': 'marathon',
    'needsRunnerDetails': true,
    'ticketTypes': [
      {'name': '10K', 'description': 'Fun run', 'priceCents': 1500},
      {'name': '21K', 'description': '', 'priceCents': 2500},
    ],
  };
}

const tripId = '01a1dfa0-0000-7000-8000-000000000015';

Map<String, dynamic> busRouteJson() {
  return {
    'id': 'phnom-penh-siem-reap',
    'origin': 'Phnom Penh',
    'destination': 'Siem Reap',
    'durationMinutes': 360,
    'operatorCount': 2,
    'tripCount': 3,
    'fromPriceCents': 1400,
  };
}

/// A trip as `GET /catalog/bus/departures` sends it.
Map<String, dynamic> busDepartureJson() {
  return {
    'id': tripId,
    'routeId': 'phnom-penh-siem-reap',
    'operatorName': 'Giant Ibis',
    'operatorCode': 'GI',
    'operatorColor': 0xFF1E8A72,
    'coachType': 'Seater · 2+2',
    'origin': 'Phnom Penh',
    'destination': 'Siem Reap',
    'departsAt': '2026-11-20T08:45:00',
    'durationMinutes': 360,
    'priceCents': 1500,
    'amenities': ['Wi-Fi', 'A/C'],
    'seatsLeft': 18,
    'boardingPoint': 'Giant Ibis Terminal, Phnom Penh',
    'boardingAddress': 'St 106, Riverside, Phnom Penh',
    'about': 'Two days at Angkor.',
  };
}

/// A bus trip as the event inside a booking.
Map<String, dynamic> busEventJson() {
  return {
    'id': tripId,
    'name': 'Phnom Penh to Siem Reap',
    'startsAt': '2026-11-20T08:45:00',
    'venue': 'Giant Ibis Terminal, Phnom Penh',
    'venueDetail': 'St 106, Riverside, Phnom Penh',
    'about': 'Two days at Angkor.',
    'organiser': 'Giant Ibis',
    'policy': '',
    'kind': 'bus',
    'needsRunnerDetails': false,
    'ticketTypes': [
      {'name': 'Seat', 'description': '', 'priceCents': 1500},
    ],
    'bus': {
      'origin': 'Phnom Penh',
      'destination': 'Siem Reap',
      'durationMinutes': 360,
      'coachType': 'seater',
      'coachLabel': 'Seater · 2+2',
      'amenities': ['Wi-Fi', 'A/C'],
      'operatorCode': 'GI',
      'operatorColor': 0xFF1E8A72,
    },
  };
}

Map<String, dynamic> busBookingJson({String id = 'TK61752194', String status = 'open'}) {
  return {
    'id': id,
    'status': status,
    'holderName': 'Sokha Chan',
    'payment': 'card',
    'promoCode': null,
    'discountCents': 0,
    'subtotalCents': 3000,
    'totalCents': 3000,
    'bookedAt': '2026-11-14T09:30:00',
    'lines': [
      {'ticketType': 'Seat', 'quantity': 2, 'unitPriceCents': 1500},
    ],
    'seats': ['1A', '1B'],
    'event': busEventJson(),
    'runner': null,
    'cancellation': null,
  };
}

/// A 2+2 coach's first two rows, as `GET /catalog/bus/departures/{id}/seats` sends them.
Map<String, dynamic> busSeatsJson() {
  Map<String, dynamic> seat(String id, String column, String status) => {
    'id': id,
    'label': id,
    'detail': 'Row ${id[0]} · ${column == 'A' || column == 'D' ? 'Window' : 'Aisle'}',
    'status': status,
  };
  return {
    'seatType': 'Seater · 2+2',
    'priceCents': 1500,
    'rows': [
      [seat('1A', 'A', 'takenByFemale'), seat('1B', 'B', 'takenByMale'), null, seat('1C', 'C', 'taken'), seat('1D', 'D', 'available')],
      [seat('2A', 'A', 'available'), seat('2B', 'B', 'available'), null, seat('2C', 'C', 'available'), seat('2D', 'D', 'available')],
    ],
  };
}

const placeId = '01a1dfa0-0000-7000-8000-000000000041';

/// A place as `GET /catalog/places` sends it, and as the event inside a booking.
Map<String, dynamic> placeJson({String kind = 'admission'}) {
  return {
    'id': placeId,
    'name': 'Phnom Tamao Wildlife Rescue Centre',
    'venue': 'Phnom Tamao',
    'venueDetail': 'Takeo, 40km from Phnom Penh',
    'about': 'Elephants, tigers and sun bears.',
    'organiser': 'Wildlife Alliance',
    'policy': 'Refundable up to the day before',
    'kind': kind,
    'ticketTypes': [
      {'name': 'Adult', 'description': '', 'priceCents': 500, 'dailyLimit': 60},
      {'name': 'Child', 'description': 'Under 12', 'priceCents': 200, 'dailyLimit': null},
    ],
  };
}

Map<String, dynamic> placeBookingJson({String id = 'TK91000000', String status = 'open'}) {
  return {
    'id': id,
    'status': status,
    'holderName': 'Sokha Chan',
    'payment': 'card',
    'promoCode': null,
    'discountCents': 0,
    'subtotalCents': 1400,
    'totalCents': 1400,
    'bookedAt': '2026-11-14T09:30:00',
    'lines': [
      {'ticketType': 'Adult', 'quantity': 2, 'unitPriceCents': 500},
      {'ticketType': 'Child', 'quantity': 2, 'unitPriceCents': 200},
    ],
    'seats': <Object?>[],
    'visitDate': '2026-11-28',
    'event': placeJson(),
    'runner': null,
    'cancellation': null,
  };
}

const screeningId = '01a1dfa0-0000-7000-8000-000000000031';

/// A film as `GET /catalog/cinema/films` sends it.
Map<String, dynamic> filmJson() {
  return {
    'id': 'skyline-run',
    'name': 'Skyline Run',
    'rating': 'PG-13',
    'genre': 'Action',
    'runtimeMinutes': 128,
    'about': 'A courier has 90 minutes to cross a city.',
    'policy': 'Non-refundable once seats are issued',
    'fromPriceCents': 600,
    'firstShowingOn': '2026-11-20',
  };
}

/// A film's showtimes at one cinema, as `GET /catalog/cinema/films/{id}/showtimes` sends them.
Map<String, dynamic> theatreShowtimesJson() {
  return {
    'theatre': {'id': 'legend-cinema-aeon-mall', 'name': 'Legend Cinema, Aeon Mall', 'area': 'Aeon Mall, Phnom Penh'},
    'showtimes': [
      {'id': screeningId, 'startsAt': '2026-11-20T21:00:00', 'hall': 'Hall 2', 'priceCents': 700, 'seatsLeft': 75},
    ],
  };
}

/// A screening as the event inside a booking.
Map<String, dynamic> cinemaEventJson() {
  return {
    'id': screeningId,
    'name': 'Skyline Run',
    'startsAt': '2026-11-20T21:00:00',
    'venue': 'Legend Cinema, Aeon Mall',
    'venueDetail': 'Aeon Mall, Phnom Penh',
    'about': 'A courier has 90 minutes to cross a city.',
    'organiser': 'Legend Cinema',
    'policy': 'Non-refundable once seats are issued',
    'kind': 'cinema',
    'needsRunnerDetails': false,
    'ticketTypes': [
      {'name': 'Seat', 'description': '', 'priceCents': 700},
    ],
    'bus': null,
    'screening': {
      'filmId': 'skyline-run',
      'rating': 'PG-13',
      'genre': 'Action',
      'runtimeMinutes': 128,
      'hall': 'Hall 2',
      'hallSize': 'large',
      'hallLabel': 'Large hall · 120 seats',
    },
  };
}

Map<String, dynamic> cinemaBookingJson({String id = 'TK82001000', String status = 'open'}) {
  return {
    'id': id,
    'status': status,
    'holderName': 'Sokha Chan',
    'payment': 'card',
    'promoCode': null,
    'discountCents': 0,
    'subtotalCents': 1400,
    'totalCents': 1400,
    'bookedAt': '2026-11-14T09:30:00',
    'lines': [
      {'ticketType': 'Seat', 'quantity': 2, 'unitPriceCents': 700},
    ],
    'seats': ['F5', 'F6'],
    'event': cinemaEventJson(),
    'runner': null,
    'cancellation': null,
  };
}

/// A hall's first two rows, as `GET /catalog/cinema/showtimes/{id}/seats` sends them:
/// seats are only taken, never by a woman or a man.
Map<String, dynamic> hallSeatsJson() {
  Map<String, dynamic> seat(String row, int number, String status) => {
    'id': '$row$number',
    'label': '$number',
    'detail': 'Row $row',
    'status': status,
  };
  return {
    'seatType': 'Large hall · 120 seats',
    'priceCents': 700,
    'rows': [
      [seat('A', 1, 'taken'), seat('A', 2, 'available'), null, seat('A', 3, 'available')],
      [seat('B', 1, 'available'), seat('B', 2, 'available'), null, seat('B', 3, 'taken')],
    ],
  };
}

const runnerJson = {
  'name': 'Sokha Chan',
  'phone': '+85510222333',
  'email': null,
  'gender': 'female',
  'age': 30,
  'nationality': 'Cambodian',
  'emergencyName': 'Vanna Chan',
  'emergencyPhone': '+85512345678',
  'shirtSize': 'M',
};

Map<String, dynamic> bookingJson({
  String id = 'TK48213377',
  String status = 'open',
  Map<String, dynamic>? cancellation,
}) {
  return {
    'id': id,
    'status': status,
    'holderName': 'Sokha Chan',
    'payment': 'abaKhqr',
    'promoCode': 'D2D10',
    'discountCents': 250,
    'subtotalCents': 2500,
    'totalCents': 2250,
    'bookedAt': '2026-11-14T09:30:00',
    'lines': [
      {'ticketType': '21K', 'quantity': 1, 'unitPriceCents': 2500},
    ],
    'event': eventJson(),
    'runner': runnerJson,
    'cancellation': cancellation,
  };
}

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

  group('sign-in', () {
    late AuthApiDataSource auth;

    setUp(() => auth = AuthApiDataSource(dio));

    test('asks for a code, then verifies it as the user app', () async {
      server.answer('POST', '/auth/otp', null, status: 204);
      await auth.requestOtp(phone: '+85510222333', purpose: OtpPurpose.login);
      expect(server.last('POST', '/auth/otp').data, {'phone': '+85510222333', 'purpose': 'login'});

      server.answer('POST', '/auth/verify', {
        'session': {
          'accessToken': 'abc',
          'user': {
            'id': 'b1',
            'name': 'Sokha Chan',
            'phone': '+85510222333',
            'gender': 'female',
            'dateOfBirth': '1996-04-12',
            'email': null,
          },
        },
      });
      final response = await auth.verifyOtp(
        phone: '+85510222333',
        code: '123456',
        purpose: OtpPurpose.login,
      );

      expect(server.last('POST', '/auth/verify').data, containsPair('app', 'user'));
      expect(response.registrationToken, isNull);
      expect(response.session!.accessToken, 'abc');
      expect(response.session!.user.gender, Gender.female);
      expect(response.session!.user.dateOfBirth, DateTime(1996, 4, 12));
    });

    test('a new number gets a registration token, and registers with its details', () async {
      server.answer('POST', '/auth/verify', {'registrationToken': 'reg-1'});
      final response = await auth.verifyOtp(
        phone: '+85512888999',
        code: '123456',
        purpose: OtpPurpose.register,
      );
      expect(response.session, isNull);
      expect(response.registrationToken, 'reg-1');

      server.answer(
        'POST',
        '/buyer/register',
        {
          'accessToken': 'def',
          'user': {
            'id': 'b2',
            'name': 'Dara Pich',
            'phone': '+85512888999',
            'gender': 'male',
            'dateOfBirth': '1990-01-05',
            'email': 'dara@example.com',
          },
        },
        status: 201,
      );
      final session = await auth.register(
        registrationToken: 'reg-1',
        name: 'Dara Pich',
        gender: Gender.male,
        dateOfBirth: DateTime(1990, 1, 5),
        email: 'dara@example.com',
      );

      expect(server.last('POST', '/buyer/register').data, {
        'registrationToken': 'reg-1',
        'name': 'Dara Pich',
        'gender': 'male',
        'dateOfBirth': '1990-01-05',
        'email': 'dara@example.com',
      });
      expect(session.user.email, 'dara@example.com');
    });

    test('a wrong code is an ApiException with the code the server sent', () async {
      server.answer('POST', '/auth/verify', {'code': 'invalid_code', 'message': 'Wrong'}, status: 400);

      await expectLater(
        auth.verifyOtp(phone: '+85510222333', code: '000000', purpose: OtpPurpose.login),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.invalidCode)
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('signing out with a token the server already refused does not start another sign-out', () async {
      server.answer(
        'POST',
        '/auth/sign-out',
        {'code': 'unauthorized', 'message': 'Please sign in again.'},
        status: 401,
      );

      await expectLater(auth.signOut(), throwsA(isA<ApiException>()));

      expect(server.last('POST', '/auth/sign-out').headers['Authorization'], 'Bearer token-1');
      expect(sessionRejections, 0);
    });

    test('a 401 to a request sent without a token signs nobody out', () async {
      final signedOut = createApiClient(
        config: const AppConfig(apiBaseUrl: 'http://pin.test', useMockApi: false),
        readToken: () async => null,
        onSessionRejected: () => sessionRejections++,
      )..httpClientAdapter = server;
      server.answer(
        'POST',
        '/auth/verify',
        {'code': 'unauthorized', 'message': 'Please sign in again.'},
        status: 401,
      );

      await expectLater(
        AuthApiDataSource(signedOut).verifyOtp(
          phone: '+85510222333',
          code: '123456',
          purpose: OtpPurpose.login,
        ),
        throwsA(isA<ApiException>()),
      );

      expect(server.last('POST', '/auth/verify').headers.containsKey('Authorization'), isFalse);
      expect(sessionRejections, 0);
    });
  });

  group('catalogue', () {
    late ApiCatalogRepository repository;

    setUp(() {
      repository = ApiCatalogRepository(CatalogApiDataSource(dio));
      // Everything on sale also asks for the bus routes, the films and the places; most tests have none.
      server
        ..answer('GET', '/catalog/bus/routes', <Object?>[])
        ..answer('GET', '/catalog/cinema/films', <Object?>[])
        ..answer('GET', '/catalog/places', <Object?>[]);
    });

    test('events come from GET /catalog/events, with their ticket types', () async {
      server.answer('GET', '/catalog/events', [eventJson()]);

      final result = await repository.listings();

      final events = (result as Success<List<Listing>>).value;
      final event = events.single as EventListing;
      expect(event.name, 'Phnom Penh Half Marathon');
      expect(event.startsAt, DateTime(2026, 12, 6, 5, 30));
      expect(event.kind, EventKind.marathon);
      expect(event.needsRunnerDetails, isTrue);
      expect(event.tiers.map((t) => (t.name, t.priceCents, t.description)), [
        ('10K', 1500, 'Fun run'),
        ('21K', 2500, ''),
      ]);
      expect(server.last('GET', '/catalog/events').headers['Authorization'], 'Bearer token-1');
    });

    test('a concert or a show needs no runner details', () async {
      server.answer('GET', '/catalog/events', [
        {...eventJson(id: 'e2'), 'kind': 'show', 'needsRunnerDetails': false},
        {...eventJson(id: 'e3'), 'kind': 'concert', 'needsRunnerDetails': false},
      ]);

      final result = await repository.listings();

      final events = (result as Success<List<Listing>>).value.cast<EventListing>();
      expect(events.map((e) => e.kind), [EventKind.show, EventKind.concert]);
      expect(events.any((e) => e.needsRunnerDetails), isFalse);
    });

    test('an older server without a kind: runner details mean a marathon, else a concert', () async {
      final older = {...eventJson(id: 'e2')}..remove('kind');
      final olderConcert = {...older, 'id': 'e3', 'needsRunnerDetails': false};
      server.answer('GET', '/catalog/events', [older, olderConcert]);

      final result = await repository.listings();

      final events = (result as Success<List<Listing>>).value.cast<EventListing>();
      expect(events.map((e) => e.kind), [EventKind.marathon, EventKind.concert]);
    });

    test('places come from GET /catalog/places; a place opens by its event id, as a place', () async {
      server
        ..answer('GET', '/catalog/places', [placeJson()])
        ..answer('GET', '/catalog/events/$placeId', placeJson());

      final places = (await repository.listings(category: TicketCategory.admission) as Success<List<Listing>>).value;
      final opened = (await repository.listing(placeId) as Success<Listing>).value;

      final place = places.single as AdmissionListing;
      expect(place.id, placeId);
      expect(place.name, 'Phnom Tamao Wildlife Rescue Centre');
      expect(place.venue, 'Phnom Tamao');
      expect(place.venueDetail, 'Takeo, 40km from Phnom Penh');
      expect(place.organiser, 'Wildlife Alliance');
      expect(place.policy, 'Refundable up to the day before');
      expect(place.tiers.map((t) => (t.name, t.priceCents, t.description)), [
        ('Adult', 500, ''),
        ('Child', 200, 'Under 12'),
      ]);
      expect(place.fromPriceCents, 200);
      expect(opened, place);
    });

    test('what is left of a place on a day comes from the server; a kind with no limit is not listed', () async {
      server.answer('GET', '/catalog/places/$placeId/availability', {
        'date': '2026-11-28',
        'ticketTypes': [
          {'name': 'Adult', 'left': 2},
          {'name': 'Child', 'left': null},
        ],
      });

      final result = await repository.placeAvailability(placeId: placeId, date: DateTime(2026, 11, 28, 14, 30));

      // Only the day counts, as the server reads it.
      expect(server.last('GET', '/catalog/places/$placeId/availability').queryParameters, {'date': '2026-11-28'});
      final availability = (result as Success<PlaceAvailability>).value;
      expect(availability.leftOf('Adult'), 2);
      expect(availability.leftOf('Child'), isNull);
      expect(availability.isSoldOut('Adult'), isFalse);
      expect(const PlaceAvailability({'Adult': 0}).isSoldOut('Adult'), isTrue);
    });

    test('an event that is not on sale is NotFoundFailure with the server message', () async {
      const gone = '01a1dfa0-0000-7000-8000-0000000000aa';
      server.answer(
        'GET',
        '/catalog/events/$gone',
        {'code': 'not_found', 'message': 'This event is no longer on sale.'},
        status: 404,
      );

      final result = await repository.listing(gone);

      expect(
        result,
        const Result<Listing>.failure(NotFoundFailure('This event is no longer on sale.')),
      );
    });

    test('a film comes from GET /catalog/cinema/films, and its page by its id; one not showing is not found', () async {
      server
        ..answer('GET', '/catalog/cinema/films', [filmJson()])
        ..answer('GET', '/catalog/cinema/films/skyline-run', filmJson())
        ..answer(
          'GET',
          '/catalog/cinema/films/gone',
          {'code': 'not_found', 'message': 'This film is not showing.'},
          status: 404,
        );

      final films = (await repository.listings(category: TicketCategory.cinema) as Success<List<Listing>>).value;
      final film = (await repository.listing('skyline-run') as Success<Listing>).value as FilmListing;
      final gone = await repository.listing('gone');

      expect(films.single, film);
      expect(film.name, 'Skyline Run');
      expect(film.rating, 'PG-13');
      expect(film.genre, 'Action');
      expect(film.runtime, const Duration(minutes: 128));
      expect(film.releasedOn, DateTime(2026, 11, 20));
      expect(film.about, 'A courier has 90 minutes to cross a city.');
      expect(film.policy, 'Non-refundable once seats are issued');
      expect(film.fromPriceCents, 600);
      expect(gone, const Result<Listing>.failure(NotFoundFailure('This film is not showing.')));
    });

    test('the cover image of an event, a place and a film is read as the path the server sends; none is null', () async {
      const eventImage = '/images/events/e1?v=1763300000000';
      const placeImage = '/images/events/$placeId?v=1763300000001';
      const filmImage = '/images/events/$screeningId?v=1763300000002';
      server
        ..answer('GET', '/catalog/events', [
          {...eventJson(), 'imageUrl': eventImage},
          {...eventJson(id: 'e2'), 'imageUrl': null},
          eventJson(id: 'e3'), // an older server does not send the field at all
        ])
        ..answer('GET', '/catalog/places', [
          {...placeJson(), 'imageUrl': placeImage},
        ])
        ..answer('GET', '/catalog/cinema/films', [
          {...filmJson(), 'imageUrl': filmImage},
        ]);

      final events = (await repository.listings() as Success<List<Listing>>).value;
      final places = (await repository.listings(category: TicketCategory.admission) as Success<List<Listing>>).value;
      final films = (await repository.listings(category: TicketCategory.cinema) as Success<List<Listing>>).value;

      expect(events.whereType<EventListing>().map((e) => e.imageUrl), [eventImage, null, null]);
      expect(places.single.imageUrl, placeImage);
      expect(films.single.imageUrl, filmImage);
      // A route is many trips of many companies: it never has one picture.
      expect(const BusRoute(id: 'r', origin: 'A', destination: 'B', typicalDuration: Duration(hours: 1), operatorCount: 1, fromPriceCents: 1).imageUrl, isNull);
    });

    test('search filters the events by name, venue and where the venue is', () async {
      server.answer('GET', '/catalog/events', [
        eventJson(),
        {...eventJson(id: 'e2', name: 'Khmer Rock Night'), 'venue': 'Koh Pich Theatre', 'venueDetail': 'Diamond Island'},
      ]);

      Future<List<String>> found(String query) async {
        final result = await repository.search(query);
        return [for (final listing in (result as Success<List<Listing>>).value) listing.name];
      }

      expect(await found('marathon'), ['Phnom Penh Half Marathon']);
      expect(await found('KOH PICH'), ['Khmer Rock Night']);
      expect(await found('diamond'), ['Khmer Rock Night']);
      expect(await found('stadium'), ['Phnom Penh Half Marathon']);
      expect(await found('nothing like it'), isEmpty);
      expect(await found('  '), isEmpty);
    });

    test('the showtimes of a film come from the server by cinema, for the day asked', () async {
      server.answer('GET', '/catalog/cinema/films/skyline-run/showtimes', [theatreShowtimesJson()]);

      final result = await repository.showtimes(filmId: 'skyline-run', date: DateTime(2026, 11, 20, 14, 30));

      // Only the day counts, as the server reads it.
      expect(server.last('GET', '/catalog/cinema/films/skyline-run/showtimes').queryParameters, {
        'date': '2026-11-20',
      });
      final theatre = (result as Success<List<TheatreShowtimes>>).value.single;
      expect(theatre.theatre.id, 'legend-cinema-aeon-mall');
      expect(theatre.theatre.name, 'Legend Cinema, Aeon Mall');
      expect(theatre.theatre.area, 'Aeon Mall, Phnom Penh');
      final showtime = theatre.showtimes.single;
      expect(showtime.id, screeningId);
      expect(showtime.startsAt, DateTime(2026, 11, 20, 21));
      expect(showtime.hall, 'Hall 2');
      expect(showtime.priceCents, 700);
    });

    test('bus routes come from GET /catalog/bus/routes', () async {
      server.answer('GET', '/catalog/bus/routes', [busRouteJson()]);

      final result = await repository.listings(category: TicketCategory.bus);

      final route = (result as Success<List<Listing>>).value.single as BusRoute;
      expect(route.id, 'phnom-penh-siem-reap');
      expect(route.name, 'Phnom Penh → Siem Reap');
      expect(route.typicalDuration, const Duration(hours: 6));
      expect(route.operatorCount, 2);
      expect(route.fromPriceCents, 1400);
    });

    test('everything on sale is the events, routes, films, then places; search finds each', () async {
      server
        ..answer('GET', '/catalog/events', [eventJson()])
        ..answer('GET', '/catalog/bus/routes', [busRouteJson()])
        ..answer('GET', '/catalog/cinema/films', [filmJson()])
        ..answer('GET', '/catalog/places', [placeJson()]);

      final all = (await repository.listings() as Success<List<Listing>>).value;
      final route = (await repository.search('siem') as Success<List<Listing>>).value;
      final film = (await repository.search('SKYLINE') as Success<List<Listing>>).value;
      final genre = (await repository.search('action') as Success<List<Listing>>).value;
      final place = (await repository.search('takeo') as Success<List<Listing>>).value;

      expect(all.map((l) => l.name), [
        'Phnom Penh Half Marathon',
        'Phnom Penh → Siem Reap',
        'Skyline Run',
        'Phnom Tamao Wildlife Rescue Centre',
      ]);
      expect(route.map((l) => l.name), ['Phnom Penh → Siem Reap']);
      expect(film.map((l) => l.name), ['Skyline Run']);
      expect(genre.map((l) => l.name), ['Skyline Run']);
      expect(place.map((l) => l.name), ['Phnom Tamao Wildlife Rescue Centre']);
    });

    test('the trips of a day come from GET /catalog/bus/departures with the route and the day', () async {
      server.answer('GET', '/catalog/bus/departures', [busDepartureJson()]);

      final result = await repository.busDepartures(
        origin: 'Phnom Penh',
        destination: 'Siem Reap',
        date: DateTime(2026, 11, 20, 14, 30),
      );

      expect(server.last('GET', '/catalog/bus/departures').queryParameters, {
        'origin': 'Phnom Penh',
        'destination': 'Siem Reap',
        // Only the day counts, as the server reads it.
        'date': '2026-11-20',
      });
      final trip = (result as Success<List<BusDeparture>>).value.single;
      expect(trip.id, '01a1dfa0-0000-7000-8000-000000000015');
      expect(trip.operatorName, 'Giant Ibis');
      expect(trip.operatorCode, 'GI');
      expect(trip.operatorColor, 0xFF1E8A72);
      expect(trip.coachType, 'Seater · 2+2');
      expect(trip.departsAt, DateTime(2026, 11, 20, 8, 45));
      expect(trip.arrivesAt, DateTime(2026, 11, 20, 14, 45));
      expect(trip.priceCents, 1500);
      expect(trip.amenities, ['Wi-Fi', 'A/C']);
      expect(trip.seatsLeft, 18);
      expect(trip.boardingPoint, 'Giant Ibis Terminal, Phnom Penh');
      expect(trip.boardingAddress, 'St 106, Riverside, Phnom Penh');
    });
  });

  group('booking JSON', () {
    test('a cancelled booking keeps its cancellation, runner, tiers and payment', () {
      final booking = BookingJson.booking(
        bookingJson(
          status: 'cancelled',
          cancellation: {
            'at': '2026-11-15T10:00:00',
            'reason': 'eventChanged',
            'businessName': 'PP Runners',
            'refundCents': 2250,
          },
        ),
      );

      expect(booking.status, BookingStatus.cancelled);
      expect(
        booking.cancellation,
        BookingCancellation(
          at: DateTime(2026, 11, 15, 10),
          reason: CancellationReason.eventChanged,
          businessName: 'PP Runners',
          refundCents: 2250,
        ),
      );
      expect(booking.paidWith, PaymentMethod.abaPay);
      expect(booking.promoCode, 'D2D10');
      expect(booking.discountCents, 250);
      expect(booking.totalCents, 2250);
      expect(booking.bookedAt, DateTime(2026, 11, 14, 9, 30));
      final request = booking.request as EventRequest;
      expect(request.runner, runner);
      expect(request.lines.map((l) => (l.name, l.quantity, l.unitPriceCents)), [('21K', 1, 2500)]);
      expect(request.title, 'Phnom Penh Half Marathon');
    });

    test('open and checkedIn are confirmed and used; a booking without a runner or promo has none', () {
      final open = BookingJson.booking({...bookingJson(), 'runner': null, 'promoCode': null});
      final scanned = BookingJson.booking(bookingJson(status: 'checkedIn'));

      expect(open.status, BookingStatus.confirmed);
      expect((open.request as EventRequest).runner, isNull);
      expect(open.promoCode, isNull);
      expect(scanned.status, BookingStatus.used);
      expect(scanned.isUsed, isTrue);
      expect(scanned.cancellation, isNull);
    });

    test('an unknown reason reads as "Other reason"', () {
      final booking = BookingJson.booking(
        bookingJson(
          status: 'cancelled',
          cancellation: {
            'at': '2026-11-15T10:00:00',
            'reason': 'somethingNew',
            'businessName': 'PP Runners',
            'refundCents': 0,
          },
        ),
      );

      expect(booking.cancellation!.reason.label, 'Other reason');
    });
  });

  group('bookings', () {
    late ApiBookingRepository repository;

    setUp(() {
      repository = ApiBookingRepository(
        BookingApiDataSource(dio),
        pollEvery: const Duration(hours: 1),
      );
    });

    EventRequest raceRequest() {
      final event = BookingJson.booking(bookingJson()).request as EventRequest;
      return EventRequest(
        event: event.event,
        quantities: {event.event.tiers.last: 1},
        runner: runner,
      );
    }

    test('promotions and the saved runner come from the server', () async {
      server.answer('GET', '/buyer/promotions', [
        {
          'code': 'FIRST',
          'title': r'$2 off',
          'description': r'Orders of $5 or more',
          'percentOff': 0,
          'amountOffCents': 200,
          'minimumSpendCents': 500,
        },
      ]);
      server.answer('GET', '/buyer/runner', {'runner': runnerJson});

      final promotions = (await repository.promotions() as Success).value as List;
      final saved = await repository.savedRunner();

      expect(promotions.single.code, 'FIRST');
      expect(promotions.single.minimumSpendCents, 500);
      expect((saved as Success<RunnerDetails?>).value, runner);

      server.answer('GET', '/buyer/runner', {'runner': null});
      expect(await repository.savedRunner(), const Result<RunnerDetails?>.success(null));
    });

    test('placing an order sends tier names, the payment, the promo code and the runner', () async {
      server.answer('POST', '/buyer/bookings', bookingJson(), status: 201);

      final result = await repository.placeOrder(
        Order(
          request: raceRequest(),
          paymentMethod: PaymentMethod.abaPay,
          promoCode: 'D2D10',
          saveRunner: true,
        ),
      );

      expect(server.last('POST', '/buyer/bookings').data, {
        'eventId': 'e1',
        'lines': [
          {'ticketType': '21K', 'quantity': 1},
        ],
        'payment': 'abaKhqr',
        'promoCode': 'D2D10',
        // No email was given, so none is sent.
        'runner': {...runnerJson}..remove('email'),
        'saveRunner': true,
      });
      expect((result as Success<Booking>).value.id, 'TK48213377');
    });

    test('a card order without a promo code or runner sends neither', () async {
      server.answer('POST', '/buyer/bookings', bookingJson(), status: 201);
      final event = (BookingJson.booking(bookingJson()).request as EventRequest).event;

      await repository.placeOrder(
        Order(
          request: EventRequest(event: event, quantities: {event.tiers.first: 2}),
          paymentMethod: PaymentMethod.card,
        ),
      );

      expect(server.last('POST', '/buyer/bookings').data, {
        'eventId': 'e1',
        'lines': [
          {'ticketType': '10K', 'quantity': 2},
        ],
        'payment': 'card',
      });
    });

    test("the server's reason for refusing an order reaches the person", () async {
      server.answer(
        'POST',
        '/buyer/bookings',
        {'code': 'rejected', 'message': 'Only 2 tickets left.'},
        status: 409,
      );

      final result = await repository.placeOrder(
        Order(request: raceRequest(), paymentMethod: PaymentMethod.card),
      );

      expect(result, const Result<Booking>.failure(RejectedFailure('Only 2 tickets left.')));
    });

    test('a bus booking is a BusRequest with its trip, coach, route and seats', () {
      final booking = BookingJson.booking(busBookingJson());

      final request = booking.request as BusRequest;
      expect(request.departure.id, tripId);
      expect(request.departure.routeId, 'phnom-penh-siem-reap');
      expect(request.departure.operatorName, 'Giant Ibis');
      expect(request.departure.coachType, 'Seater · 2+2');
      expect(request.departure.departsAt, DateTime(2026, 11, 20, 8, 45));
      expect(request.departure.boardingPoint, 'Giant Ibis Terminal, Phnom Penh');
      expect(request.departure.priceCents, 1500);
      expect(request.seats.map((seat) => seat.id), ['1A', '1B']);
      expect(request.subtotalCents, 3000);
      expect(booking.totalCents, 3000);
      expect(booking.status, BookingStatus.confirmed);
    });

    test('a cancelled bus booking keeps its seats and its cancellation', () {
      final booking = BookingJson.booking({
        ...busBookingJson(status: 'cancelled'),
        'cancellation': {
          'at': '2026-11-15T10:00:00',
          'reason': 'eventChanged',
          'businessName': 'Giant Ibis',
          'refundCents': 3000,
        },
      });

      expect((booking.request as BusRequest).seats, hasLength(2));
      expect(booking.isCancelled, isTrue);
      expect(booking.cancellation!.refundCents, 3000);
    });

    test('the seats of a trip come from the server with who sits where', () async {
      server.answer('GET', '/catalog/bus/departures/$tripId/seats', busSeatsJson());
      final departure = (BookingJson.booking(busBookingJson()).request as BusRequest).departure;

      final result = await repository.busSeats(departure);

      final map = (result as Success<SeatMap>).value;
      expect(map.seatType, 'Seater · 2+2');
      expect(map.priceCents, 1500);
      expect(map.rows.first[2], isNull);
      expect(map.seat('1A')!.status, SeatStatus.takenByFemale);
      expect(map.seat('1B')!.status, SeatStatus.takenByMale);
      expect(map.seat('1C')!.status, SeatStatus.taken);
      expect(map.seat('1D')!.status, SeatStatus.available);
      expect(map.seat('1A')!.detail, 'Row 1 · Window');
    });

    test('a bus order sends the trip and the seat ids, with the payment and the promo code', () async {
      server.answer('POST', '/buyer/bookings', busBookingJson(), status: 201);
      final request = BookingJson.booking(busBookingJson()).request as BusRequest;

      final result = await repository.placeOrder(
        Order(request: request, paymentMethod: PaymentMethod.card, promoCode: 'D2D10'),
      );

      expect(server.last('POST', '/buyer/bookings').data, {
        'eventId': tripId,
        'seats': ['1A', '1B'],
        'payment': 'card',
        'promoCode': 'D2D10',
      });
      expect((result as Success<Booking>).value.id, 'TK61752194');
    });

    test('a seat taken meanwhile is the answer the person sees', () async {
      server.answer(
        'POST',
        '/buyer/bookings',
        {'code': 'rejected', 'message': 'Seat 1A has just been taken. Choose another seat.'},
        status: 409,
      );
      final request = BookingJson.booking(busBookingJson()).request;

      final result = await repository.placeOrder(Order(request: request, paymentMethod: PaymentMethod.abaPay));

      expect(
        result,
        const Result<Booking>.failure(RejectedFailure('Seat 1A has just been taken. Choose another seat.')),
      );
    });

    test('a cinema booking is a CinemaRequest with its film, cinema, showtime and seats', () {
      final booking = BookingJson.booking(cinemaBookingJson());

      final request = booking.request as CinemaRequest;
      expect(request.film.id, 'skyline-run');
      expect(request.film.name, 'Skyline Run');
      expect(request.film.rating, 'PG-13');
      expect(request.film.runtime, const Duration(minutes: 128));
      expect(request.theatre.id, 'legend-cinema-aeon-mall');
      expect(request.theatre.name, 'Legend Cinema, Aeon Mall');
      expect(request.theatre.area, 'Aeon Mall, Phnom Penh');
      expect(request.showtime.id, screeningId);
      expect(request.showtime.hall, 'Hall 2');
      expect(request.showtime.startsAt, DateTime(2026, 11, 20, 21));
      expect(request.showtime.priceCents, 700);
      expect(request.seats.map((seat) => seat.id), ['F5', 'F6']);
      expect(request.snacks, isEmpty);
      expect(request.title, 'Skyline Run');
      expect(request.place, 'Legend Cinema, Aeon Mall');
      expect(request.placeDetail, 'Hall 2');
      expect(request.subtotalCents, 1400);
      expect(booking.status, BookingStatus.confirmed);
    });

    test('the seats of a screening come from the server: a hall has a screen, and seats are only taken', () async {
      server.answer('GET', '/catalog/cinema/showtimes/$screeningId/seats', hallSeatsJson());
      final showtime = (BookingJson.booking(cinemaBookingJson()).request as CinemaRequest).showtime;

      final result = await repository.cinemaSeats(showtime);

      final map = (result as Success<SeatMap>).value;
      expect(map.hasScreen, isTrue);
      expect(map.seatType, 'Large hall · 120 seats');
      expect(map.priceCents, 700);
      expect(map.rows.first[2], isNull);
      expect(map.seat('A1')!.status, SeatStatus.taken);
      expect(map.seat('A2')!.status, SeatStatus.available);
      expect(map.seat('B3')!.status, SeatStatus.taken);
      expect(map.seat('A2')!.label, '2');
      expect(map.seat('A2')!.detail, 'Row A');
    });

    test('a cinema order sends the screening and the seat ids, with the payment and the promo code', () async {
      server.answer('POST', '/buyer/bookings', cinemaBookingJson(), status: 201);
      final request = BookingJson.booking(cinemaBookingJson()).request as CinemaRequest;

      final result = await repository.placeOrder(
        Order(request: request, paymentMethod: PaymentMethod.abaPay, promoCode: 'D2D10'),
      );

      expect(server.last('POST', '/buyer/bookings').data, {
        'eventId': screeningId,
        'seats': ['F5', 'F6'],
        'payment': 'abaKhqr',
        'promoCode': 'D2D10',
      });
      expect((result as Success<Booking>).value.id, 'TK82001000');
    });

    test('snacks are not on the server: they say so, and money is never taken for them', () async {
      final cinema = (BookingJson.booking(cinemaBookingJson()).request as CinemaRequest);
      const snack = Snack(id: 'popcorn', name: 'Popcorn', description: '', priceCents: 300);
      final snacks = await repository.snacks(theatreId: 'legend-cinema-aeon-mall');
      final withSnack = await repository.placeOrder(
        Order(request: CinemaRequest(
          film: cinema.film,
          theatre: cinema.theatre,
          showtime: cinema.showtime,
          seats: cinema.seats,
          snacks: {snack: 1},
        ), paymentMethod: PaymentMethod.card),
      );

      expect((snacks as FailureResult<Object?>).failure, const RejectedFailure('Cinema tickets are coming soon.'));
      expect((withSnack as FailureResult<Object?>).failure, const RejectedFailure('Snacks are coming soon.'));
      expect(server.requests, isEmpty);
    });

    test('a place booking is an AdmissionRequest for its visit day, with its tickets by type', () {
      final booking = BookingJson.booking(placeBookingJson());

      final request = booking.request as AdmissionRequest;
      expect(request.attraction.id, placeId);
      expect(request.attraction.name, 'Phnom Tamao Wildlife Rescue Centre');
      expect(request.day, DateTime(2026, 11, 28));
      expect(request.startsAt, DateTime(2026, 11, 28));
      expect(request.title, 'Phnom Tamao Wildlife Rescue Centre');
      expect(request.place, 'Phnom Tamao');
      expect(request.placeDetail, 'Takeo, 40km from Phnom Penh');
      expect(request.lines.map((l) => (l.name, l.quantity, l.unitPriceCents)), [
        ('Adult', 2, 500),
        ('Child', 2, 200),
      ]);
      expect(request.ticketCount, 4);
      expect(request.subtotalCents, 1400);
      expect(booking.status, BookingStatus.confirmed);
    });

    test('a booking carries its event\'s cover image into the ticket, whatever the kind', () {
      const image = '/images/events/e?v=5';
      Map<String, dynamic> withImage(Map<String, dynamic> booking) => {
        ...booking,
        'event': {...(booking['event'] as Map<String, dynamic>), 'imageUrl': image},
      };

      final event = BookingJson.booking(withImage(bookingJson())).request;
      final bus = BookingJson.booking(withImage(busBookingJson())).request;
      final cinema = BookingJson.booking(withImage(cinemaBookingJson())).request;
      final place = BookingJson.booking(withImage(placeBookingJson())).request;
      final without = BookingJson.booking(busBookingJson()).request;

      expect([event.imageUrl, bus.imageUrl, cinema.imageUrl, place.imageUrl], [image, image, image, image]);
      expect(without.imageUrl, isNull);
    });

    test('a place order sends the tickets by type and the visit day, with the payment and the promo code', () async {
      server.answer('POST', '/buyer/bookings', placeBookingJson(), status: 201);
      final request = BookingJson.booking(placeBookingJson()).request as AdmissionRequest;

      final result = await repository.placeOrder(
        Order(request: request, paymentMethod: PaymentMethod.abaPay, promoCode: 'D2D10'),
      );

      expect(server.last('POST', '/buyer/bookings').data, {
        'eventId': placeId,
        'lines': [
          {'ticketType': 'Adult', 'quantity': 2},
          {'ticketType': 'Child', 'quantity': 2},
        ],
        'payment': 'abaKhqr',
        'visitDate': '2026-11-28',
        'promoCode': 'D2D10',
      });
      expect((result as Success<Booking>).value.id, 'TK91000000');
    });

    test('a day sold out or over the limit is the answer the person sees', () async {
      server.answer(
        'POST',
        '/buyer/bookings',
        {'code': 'rejected', 'message': 'Only 2 left for Adult.'},
        status: 409,
      );
      final request = BookingJson.booking(placeBookingJson()).request;

      final result = await repository.placeOrder(Order(request: request, paymentMethod: PaymentMethod.card));

      expect(result, const Result<Booking>.failure(RejectedFailure('Only 2 left for Adult.')));
    });

    test('bookings are polled, and a new one shows at once', () async {
      server.answer('GET', '/buyer/bookings', [bookingJson(id: 'TK00000001')]);
      final lists = <Result<List<Booking>>>[];
      final watch = repository.watchBookings().listen(lists.add);
      await settle();
      expect((lists.last as Success<List<Booking>>).value.map((b) => b.id), ['TK00000001']);

      server.answer('POST', '/buyer/bookings', bookingJson(id: 'TK00000002'), status: 201);
      await repository.placeOrder(Order(request: raceRequest(), paymentMethod: PaymentMethod.card));
      await settle();

      expect((lists.last as Success<List<Booking>>).value.map((b) => b.id), ['TK00000001', 'TK00000002']);
      // No extra poll was needed for it.
      expect(server.requests.where((r) => r.method == 'GET' && r.path == '/buyer/bookings'), hasLength(1));
      await watch.cancel();
    });

    test('a booking the business cancelled shows as cancelled after the next poll', () async {
      final polling = ApiBookingRepository(
        BookingApiDataSource(dio),
        pollEvery: const Duration(milliseconds: 100),
      );
      server.answer('GET', '/buyer/bookings', [bookingJson()]);
      final lists = <Result<List<Booking>>>[];
      final watch = polling.watchBookings().listen(lists.add);
      await settle();
      expect((lists.last as Success<List<Booking>>).value.single.isCancelled, isFalse);

      server.answer('GET', '/buyer/bookings', [
        bookingJson(
          status: 'cancelled',
          cancellation: {
            'at': '2026-11-15T10:00:00',
            'reason': 'soldByMistake',
            'businessName': 'PP Runners',
            'refundCents': 2250,
          },
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect((lists.last as Success<List<Booking>>).value.single.isCancelled, isTrue);
      await watch.cancel();
    });

    test('a booking by ID comes from GET /buyer/bookings/{id}; an unknown one is not found', () async {
      server.answer('GET', '/buyer/bookings/TK48213377', bookingJson());
      server.answer(
        'GET',
        '/buyer/bookings/TK00000000',
        {'code': 'not_found', 'message': "This booking can't be found."},
        status: 404,
      );

      expect(((await repository.booking('TK48213377')) as Success<Booking>).value.holderName, 'Sokha Chan');
      expect(
        await repository.booking('TK00000000'),
        const Result<Booking>.failure(NotFoundFailure("This booking can't be found.")),
      );
    });

    test('a refused token signs the person out, once', () async {
      server.answer('GET', '/buyer/bookings/TK48213377', {'code': 'unauthorized', 'message': 'Expired'}, status: 401);

      final result = await repository.booking('TK48213377');

      expect(result, const Result<Booking>.failure(SessionExpiredFailure()));
      expect(sessionRejections, 1);
    });
  });
}
