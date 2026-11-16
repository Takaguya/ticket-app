import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/result/result.dart';
import 'package:user/core/storage/key_value_store.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:user/features/auth/data/datasources/auth_mock_data_source.dart';
import 'package:user/features/auth/data/models/auth_session_model.dart';
import 'package:user/features/auth/data/models/pin_user_model.dart';
import 'package:user/features/auth/domain/entities/gender.dart';
import 'package:user/features/auth/domain/entities/pin_user.dart';
import 'package:user/features/booking/data/repositories/mock_booking_repository.dart';
import 'package:user/features/booking/domain/entities/booking.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/domain/entities/order.dart';
import 'package:user/features/booking/domain/usecases/watch_bookings.dart';
import 'package:user/features/booking/presentation/bloc/bookings/bookings_bloc.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/mock_backend/mock_bookings.dart';
import 'package:user/mock_backend/mock_catalog.dart';

void main() {
  // Sunday 15 Nov 2026, 08:00.
  final now = DateTime(2026, 11, 15, 8);
  final catalog = MockCatalog(clock: FixedClock(now));
  final sokha = AuthSessionModel(
    accessToken: 'test',
    user: PinUserModel(
      id: 'u_1',
      name: 'Sokha Chan',
      phone: AuthMockDataSource.demoPhone,
      gender: Gender.female,
      dateOfBirth: DateTime(1996, 4, 12),
    ),
  );
  final dara = PinUser(
    id: 'u_2',
    name: 'Dara Pich',
    phone: '+85512888999',
    gender: Gender.male,
    dateOfBirth: DateTime(1990, 1, 1),
  );

  late AuthLocalDataSource session;
  late MockBookings bookings;
  late MockBookingRepository repository;

  setUp(() async {
    // Sokha, the demo account, is signed in on this device. She starts with
    // the film in two days (TK48213377), the bus twelve days ago
    // (TK30571942) and the rock night in a week that its organiser
    // cancelled (TK55012468).
    session = AuthLocalDataSource(InMemoryKeyValueStore());
    await session.saveSession(sokha);
    bookings = MockBookings(catalog: catalog);
    repository = MockBookingRepository(
      bookings: bookings,
      session: session,
      latency: Duration.zero,
      paymentLatency: Duration.zero,
    );
  });

  /// The list as seen at [at].
  BookingsBloc build({DateTime? at}) {
    return BookingsBloc(watchBookings: WatchBookings(repository), clock: FixedClock(at ?? now))
      ..add(const BookingsStarted());
  }

  Future<BookingsState> listed(BookingsBloc bloc, {required int count}) {
    return bloc.stream.firstWhere(
      (state) => state.status == BookingsStatus.loaded && state.bookings.length == count,
    );
  }

  /// One seat on today's 09:30 Virak Buntham to Siem Reap.
  Future<Booking> bookTodaysBus() async {
    final departure = catalog
        .departures(origin: 'Phnom Penh', destination: 'Siem Reap', date: now)
        .firstWhere((d) => d.operatorCode == 'VB');
    final seat = bookings
        .busSeats(departure)
        .rows
        .expand((row) => row)
        .nonNulls
        .firstWhere((s) => !s.status.isTaken);
    final result = await repository.placeOrder(
      Order(
        request: BusRequest(departure: departure, seats: [seat]),
        paymentMethod: PaymentMethod.abaPay,
      ),
    );
    return (result as Success<Booking>).value;
  }

  test('lists the bookings, then one made elsewhere in the app by itself', () async {
    final bloc = build();
    final first = await listed(bloc, count: 3);
    // A cancelled booking stays in its place, marked cancelled.
    expect(first.upcoming.map((b) => b.id), ['TK48213377', 'TK55012468']);
    expect(first.upcoming.last.isCancelled, isTrue);
    expect(first.past.map((b) => b.id), ['TK30571942']);

    final next = listed(bloc, count: 4);
    final bus = await bookTodaysBus();

    // Soonest first: today's bus, then the film, then the rock night.
    expect((await next).upcoming.map((b) => b.id), [bus.id, 'TK48213377', 'TK55012468']);
    await bloc.close();
  });

  test('a booking is upcoming until the end of its day, then past', () async {
    final bus = await bookTodaysBus();

    final lateEvening = build(at: DateTime(2026, 11, 15, 23, 59));
    expect((await listed(lateEvening, count: 4)).upcoming.map((b) => b.id), contains(bus.id));

    final nextDay = build(at: DateTime(2026, 11, 16, 0, 1));
    final state = await listed(nextDay, count: 4);
    expect(state.upcoming.map((b) => b.id), ['TK48213377', 'TK55012468']);
    // The most recent first.
    expect(state.past.map((b) => b.id), [bus.id, 'TK30571942']);

    await lateEvening.close();
    await nextDay.close();
  });

  test('signed out, it says why; "Try again" once signed in shows the list', () async {
    await session.clearSession();
    final bloc = build();
    final failed = await bloc.stream.firstWhere((s) => s.status == BookingsStatus.failure);
    expect(failed.errorMessage, 'Please log in again.');

    await session.saveSession(sokha);
    bloc.add(const BookingsStarted());
    expect((await listed(bloc, count: 3)).status, BookingsStatus.loaded);
    await bloc.close();
  });

  test('a refresh that fails keeps the list already shown', () async {
    final bloc = build();
    await listed(bloc, count: 3);
    // A second watcher shows that the refresh below does fail.
    final answers = <Result<List<Booking>>>[];
    final watcher = repository.watchBookings().listen(answers.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Signed out meanwhile, then someone else books, so the lists refresh.
    await session.clearSession();
    final rock = catalog.byId('ev1')! as EventListing;
    bookings.place(
      dara,
      Order(
        request: EventRequest(event: rock, quantities: {rock.tiers.first: 1}),
        paymentMethod: PaymentMethod.card,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(answers.last, isA<FailureResult<List<Booking>>>());
    expect(bloc.state.status, BookingsStatus.loaded);
    expect(bloc.state.bookings.map((b) => b.id), ['TK30571942', 'TK48213377', 'TK55012468']);
    await watcher.cancel();
    await bloc.close();
  });
}
