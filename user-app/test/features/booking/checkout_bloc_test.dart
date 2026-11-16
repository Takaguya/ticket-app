import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/result/result.dart';
import 'package:user/core/storage/key_value_store.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:user/features/auth/data/models/auth_session_model.dart';
import 'package:user/features/auth/data/models/pin_user_model.dart';
import 'package:user/features/auth/domain/entities/gender.dart';
import 'package:user/features/booking/data/repositories/mock_booking_repository.dart';
import 'package:user/features/booking/domain/entities/booking.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/domain/entities/order.dart';
import 'package:user/features/booking/domain/usecases/get_promotions.dart';
import 'package:user/features/booking/domain/usecases/place_order.dart';
import 'package:user/features/booking/presentation/bloc/checkout/checkout_bloc.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/mock_backend/mock_bookings.dart';
import 'package:user/mock_backend/mock_catalog.dart';

void main() {
  // Sunday 15 Nov 2026, 08:00.
  final clock = FixedClock(DateTime(2026, 11, 15, 8));
  final catalog = MockCatalog(clock: clock);
  final rock = catalog.byId('ev1')! as EventListing;
  late MockBookingRepository repository;

  setUp(() async {
    // Dara is signed in on this device.
    final session = AuthLocalDataSource(InMemoryKeyValueStore());
    await session.saveSession(
      AuthSessionModel(
        accessToken: 'test',
        user: PinUserModel(
          id: 'u_2',
          name: 'Dara Pich',
          phone: '+85512888999',
          gender: Gender.male,
          dateOfBirth: DateTime(1990, 1, 1),
        ),
      ),
    );
    repository = MockBookingRepository(
      bookings: MockBookings(catalog: catalog),
      session: session,
      latency: Duration.zero,
      paymentLatency: Duration.zero,
    );
  });

  CheckoutBloc build(BookingRequest request) {
    return CheckoutBloc(
      getPromotions: GetPromotions(repository),
      placeOrder: PlaceOrder(repository),
      request: request,
    );
  }

  EventRequest rockNight(int tickets) {
    return EventRequest(event: rock, quantities: {rock.tiers.first: tickets});
  }

  blocTest<CheckoutBloc, CheckoutState>(
    'a promo code is checked before it is applied',
    build: () => build(rockNight(2)),
    act: (bloc) async {
      bloc.add(const CheckoutStarted());
      await bloc.stream.firstWhere((state) => state.promotions.isNotEmpty);
      bloc
        ..add(const CheckoutPromoCodeEntered('nope'))
        ..add(const CheckoutPromoCodeEntered(' d2d10 '));
    },
    expect: () => [
      isA<CheckoutState>().having((s) => s.promotions, 'offers', hasLength(2)),
      isA<CheckoutState>().having((s) => s.notice, 'notice', 'NOPE is not a valid promo code.'),
      isA<CheckoutState>().having((s) => s.notice, 'notice', isNull),
      isA<CheckoutState>().having((s) => s.promotion?.code, 'promotion', 'D2D10'),
      isA<CheckoutState>().having((s) => s.notice, 'notice', 'D2D10 applied: 10% off tickets'),
      isA<CheckoutState>().having((s) => s.notice, 'notice', isNull),
    ],
    verify: (bloc) {
      // $30 less 10%.
      expect(bloc.state.discountCents, 300);
      expect(bloc.state.totalCents, 2700);
    },
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'Confirm pays and issues the tickets',
    build: () => build(rockNight(1)),
    act: (bloc) => bloc
      ..add(const CheckoutPaymentMethodChosen(PaymentMethod.card))
      ..add(const CheckoutConfirmed()),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.status, CheckoutStatus.paid);
      final booking = bloc.state.booking!;
      expect(booking.id, matches(RegExp(r'^TK\d{8}$')));
      expect(booking.paidWith, PaymentMethod.card);
      expect(booking.holderName, 'Dara Pich');
      expect(booking.totalCents, 1500);
    },
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'a second Confirm while paying is ignored: one payment, one booking',
    build: () => build(rockNight(1)),
    act: (bloc) => bloc
      ..add(const CheckoutConfirmed())
      ..add(const CheckoutConfirmed()),
    wait: const Duration(milliseconds: 10),
    expect: () => [
      isA<CheckoutState>().having((s) => s.status, 'status', CheckoutStatus.paying),
      isA<CheckoutState>().having((s) => s.status, 'status', CheckoutStatus.paid),
    ],
    verify: (bloc) async {
      final mine = await repository.watchBookings().first;
      expect((mine as Success<List<Booking>>).value.map((b) => b.id), [bloc.state.booking!.id]);
    },
  );

  blocTest<CheckoutBloc, CheckoutState>(
    r'FIRST is refused on an order under $5 before anything is paid',
    build: () {
      final tamao = catalog.byId('ad3')! as AdmissionListing;
      // One $2 child ticket.
      return build(
        AdmissionRequest(attraction: tamao, day: clock.now(), quantities: {tamao.tiers.last: 1}),
      );
    },
    act: (bloc) async {
      bloc.add(const CheckoutStarted());
      await bloc.stream.firstWhere((state) => state.promotions.isNotEmpty);
      bloc.add(const CheckoutPromoCodeEntered('first'));
    },
    skip: 1,
    expect: () => [
      isA<CheckoutState>().having((s) => s.notice, 'notice', r'FIRST needs an order of $5.00 or more.'),
      isA<CheckoutState>().having((s) => s.notice, 'notice', isNull),
    ],
    verify: (bloc) {
      expect(bloc.state.promotion, isNull);
      expect(bloc.state.totalCents, 200);
    },
  );

  group('a seat sold in the meantime', () {
    final departure = catalog
        .departures(origin: 'Phnom Penh', destination: 'Siem Reap', date: clock.now())
        .firstWhere((d) => d.operatorCode == 'VB');
    final seat = MockBookings(catalog: catalog)
        .busSeats(departure)
        .rows
        .expand((row) => row)
        .nonNulls
        .firstWhere((s) => !s.status.isTaken);
    final request = BusRequest(departure: departure, seats: [seat]);

    blocTest<CheckoutBloc, CheckoutState>(
      'is reported, and checkout can be tried again',
      build: () => build(request),
      act: (bloc) async {
        await repository.placeOrder(Order(request: request, paymentMethod: PaymentMethod.abaPay));
        bloc.add(const CheckoutConfirmed());
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<CheckoutState>().having((s) => s.status, 'status', CheckoutStatus.paying),
        isA<CheckoutState>().having((s) => s.status, 'status', CheckoutStatus.ready),
        isA<CheckoutState>().having(
          (s) => s.notice,
          'notice',
          'Seat ${seat.id} has just been taken. Choose another seat.',
        ),
        isA<CheckoutState>().having((s) => s.notice, 'notice', isNull),
      ],
    );
  });
}
