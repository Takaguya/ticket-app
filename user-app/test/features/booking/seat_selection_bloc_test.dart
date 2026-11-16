import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/storage/key_value_store.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:user/features/auth/domain/entities/gender.dart';
import 'package:user/features/auth/domain/entities/pin_user.dart';
import 'package:user/features/booking/data/repositories/mock_booking_repository.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/domain/entities/order.dart';
import 'package:user/features/booking/domain/entities/seat_map.dart';
import 'package:user/features/booking/domain/usecases/get_seat_map.dart';
import 'package:user/features/booking/presentation/bloc/seat_selection/seat_selection_bloc.dart';
import 'package:user/mock_backend/mock_bookings.dart';
import 'package:user/mock_backend/mock_catalog.dart';

void main() {
  // Sunday 15 Nov 2026, 08:00.
  final clock = FixedClock(DateTime(2026, 11, 15, 8));
  final catalog = MockCatalog(clock: clock);
  // Today's 13:00 Larryta Express to Siem Reap: a 2+2 coach, partly sold.
  final larryta = catalog
      .departures(origin: 'Phnom Penh', destination: 'Siem Reap', date: clock.now())
      .firstWhere((d) => d.operatorCode == 'LR');
  final dara = PinUser(
    id: 'u_2',
    name: 'Dara Pich',
    phone: '+85512888999',
    gender: Gender.male,
    dateOfBirth: DateTime(1990, 1, 1),
  );

  late MockBookings bookings;

  setUp(() {
    bookings = MockBookings(catalog: catalog);
  });

  SeatSelectionBloc build() {
    final repository = MockBookingRepository(
      bookings: bookings,
      // Seat maps are shown without signing in.
      session: AuthLocalDataSource(InMemoryKeyValueStore()),
      latency: Duration.zero,
      paymentLatency: Duration.zero,
    );
    return SeatSelectionBloc(
      getSeatMap: GetSeatMap(repository),
      request: BusRequest(departure: larryta),
    );
  }

  /// Loads the seats, again if they were loaded before.
  Future<SeatSelectionState> load(SeatSelectionBloc bloc) {
    bloc.add(const SeatSelectionStarted());
    return bloc.stream.firstWhere((state) => state.status == SeatSelectionStatus.ready);
  }

  Iterable<Seat> seatsOf(SeatSelectionState state) =>
      state.seatMap!.rows.expand((row) => row).nonNulls;

  /// Lets the bloc handle the events added so far.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('at most 8 seats in one booking, and says so', () async {
    final bloc = build();
    final notices = <String>[];
    final subscription = bloc.stream.listen((state) {
      if (state.notice case final notice?) notices.add(notice);
    });
    final free = seatsOf(await load(bloc)).where((seat) => !seat.status.isTaken).take(9).toList();

    for (final seat in free) {
      bloc.add(SeatToggled(seat));
    }
    await settle();

    expect(bloc.state.selected, free.take(8).toList());
    expect(bloc.state.chosen!.ticketCount, 8);
    expect(bloc.state.totalCents, 8 * larryta.priceCents);
    expect(notices, ['Maximum 8 seats per booking']);
    await subscription.cancel();
    await bloc.close();
  });

  test('a taken seat cannot be chosen; tapping a chosen seat lets it go', () async {
    final bloc = build();
    final seats = seatsOf(await load(bloc));
    final taken = seats.firstWhere((seat) => seat.status.isTaken);
    final free = seats.firstWhere((seat) => !seat.status.isTaken);

    bloc
      ..add(SeatToggled(taken))
      ..add(SeatToggled(free));
    await settle();
    expect(bloc.state.selected, [free]);
    expect(bloc.state.chosen, isA<BusRequest>().having((r) => r.seats, 'seats', [free]));

    bloc.add(SeatToggled(free));
    await settle();
    expect(bloc.state.selected, isEmpty);
    expect(bloc.state.chosen, isNull);
    expect(bloc.state.totalCents, 0);
    await bloc.close();
  });

  test('loading the seats again keeps those still free and lets go of one sold meanwhile', () async {
    final bloc = build();
    final free = seatsOf(await load(bloc)).where((seat) => !seat.status.isTaken).take(2).toList();
    bloc
      ..add(SeatToggled(free.first))
      ..add(SeatToggled(free.last));
    await settle();

    // Dara buys the first of the two in the meantime.
    bookings.place(
      dara,
      Order(
        request: BusRequest(departure: larryta, seats: [free.first]),
        paymentMethod: PaymentMethod.card,
      ),
    );
    final reloaded = await load(bloc);

    expect(reloaded.selected.map((seat) => seat.id), [free.last.id]);
    expect(reloaded.seatMap!.seat(free.first.id)!.status, SeatStatus.takenByMale);
    await bloc.close();
  });
}
