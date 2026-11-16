import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/media/photo_picker.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/bookings/domain/entities/check_in_result.dart';
import 'package:merchant/features/bookings/domain/repositories/bookings_repository.dart';
import 'package:merchant/features/bookings/domain/usecases/cancel_booking.dart';
import 'package:merchant/features/bookings/domain/usecases/check_in_booking.dart';
import 'package:merchant/features/bookings/domain/usecases/sell_at_door.dart';
import 'package:merchant/features/bookings/presentation/bloc/cancel_booking/cancel_booking_bloc.dart';
import 'package:merchant/features/bookings/presentation/bloc/check_in/check_in_bloc.dart';
import 'package:merchant/features/door_sale/presentation/bloc/door_sale_bloc.dart';
import 'package:merchant/features/events/domain/entities/event.dart';
import 'package:merchant/features/events/domain/repositories/events_repository.dart';
import 'package:merchant/features/events/domain/usecases/publish_bus_trip.dart';
import 'package:merchant/features/events/domain/usecases/publish_event.dart';
import 'package:merchant/features/events/domain/usecases/publish_place.dart';
import 'package:merchant/features/events/domain/usecases/publish_screening.dart';
import 'package:merchant/features/events/domain/usecases/set_event_image.dart';
import 'package:merchant/features/events/presentation/bloc/cover_photos.dart';
import 'package:merchant/features/events/presentation/bloc/create_event_bloc.dart';
import 'package:merchant/features/events/presentation/bloc/create_place_bloc.dart';
import 'package:merchant/features/events/presentation/bloc/create_screening_bloc.dart';
import 'package:merchant/features/events/presentation/bloc/create_trip_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckIn extends Mock implements CheckInBooking {}

/// For the tests of the forms that have nothing to do with pictures: the phone's gallery is never
/// opened and nothing is uploaded (see create_forms_cover_photo_test.dart for those).
class _ClosedPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

class _MockSetEventImage extends Mock implements SetEventImage {}

final _unusedPhotos = CoverPhotos(picker: _ClosedPicker(), setImage: _MockSetEventImage());

class _MockSellAtDoor extends Mock implements SellAtDoor {}

class _MockPublishEvent extends Mock implements PublishEvent {}

class _MockPublishBusTrip extends Mock implements PublishBusTrip {}

class _MockPublishScreening extends Mock implements PublishScreening {}

class _MockPublishPlace extends Mock implements PublishPlace {}

class _MockCancelBooking extends Mock implements CancelBooking {}

const _booking = Booking(
  id: 'TK12345678',
  eventId: 'e0',
  buyerName: 'Sokha Chan',
  phone: '+85510222333',
  lines: [BookingLine(ticketType: '10K', quantity: 1)],
  totalCents: 1800,
  payment: PaymentMethod.card,
  channel: SalesChannel.online,
  status: BookingStatus.cancelled,
);

void main() {
  final event = Event(
    id: 'e0',
    name: 'Phnom Penh Half Marathon 2026',
    startsAt: DateTime(2026, 11, 12, 5, 30),
    venue: 'Riverside',
    ticketTypes: const [
      TicketType(name: '5K', priceCents: 1200, quantity: 100),
      TicketType(name: '10K', priceCents: 1800, quantity: 100),
    ],
  );

  setUpAll(() {
    registerFallbackValue(const CheckInParams(eventId: '', code: ''));
    registerFallbackValue(const CancelBookingParams(bookingId: '', reason: CancelReason.other));
    registerFallbackValue(
      const DoorSaleRequest(eventId: '', lines: [], buyerPhone: '', payment: PaymentMethod.cash),
    );
    registerFallbackValue(
      EventDraft(name: '', startsAt: DateTime(2026), venue: '', ticketTypes: const []),
    );
    registerFallbackValue(
      TripDraft(
        origin: '',
        destination: '',
        startsAt: DateTime(2026),
        durationMinutes: 60,
        coach: CoachType.seater,
        priceCents: 0,
        boardingPoint: '',
      ),
    );
    registerFallbackValue(const PlaceDraft(name: '', venue: '', tickets: []));
    registerFallbackValue(
      ScreeningDraft(
        filmTitle: '',
        runtimeMinutes: 90,
        theatre: '',
        hall: '',
        hallSize: HallSize.small,
        startsAt: DateTime(2026),
        priceCents: 0,
      ),
    );
  });

  group('CheckInBloc', () {
    late _MockCheckIn checkIn;
    var now = DateTime(2026, 11, 12, 9);

    setUp(() {
      checkIn = _MockCheckIn();
      when(() => checkIn(any())).thenAnswer(
        (_) async => const Result.success(CheckInNotFound('TK11112222')),
      );
    });

    blocTest<CheckInBloc, CheckInState>(
      'ignores further scans until the result is cleared',
      build: () => CheckInBloc(checkIn: checkIn),
      act: (bloc) async {
        bloc.add(const CheckInRequested(eventId: 'e0', code: '11112222'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CheckInRequested(eventId: 'e0', code: '33334444'));
      },
      expect: () => const [
        CheckInState(status: CheckInStatus.checking),
        CheckInState(status: CheckInStatus.decided, result: CheckInNotFound('TK11112222')),
      ],
      verify: (_) => verify(() => checkIn(any())).called(1),
    );

    blocTest<CheckInBloc, CheckInState>(
      'the camera ignores the code it just answered for a few seconds, typing does not',
      build: () => CheckInBloc(checkIn: checkIn, clock: () => now),
      act: (bloc) async {
        const camera = CheckInRequested(eventId: 'e0', code: 'TK1', fromCamera: true);
        bloc.add(camera);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CheckInCleared());
        await Future<void>.delayed(Duration.zero);
        bloc.add(camera); // Same QR still in front of the camera: ignored.
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CheckInRequested(eventId: 'e0', code: 'TK1')); // Typed: allowed.
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CheckInCleared());
        await Future<void>.delayed(Duration.zero);
        now = now.add(const Duration(seconds: 5));
        bloc.add(camera); // Long enough later: allowed.
      },
      verify: (_) => verify(() => checkIn(any())).called(3),
    );

    blocTest<CheckInBloc, CheckInState>(
      'reports a failed request and becomes ready again',
      setUp: () {
        when(() => checkIn(any())).thenAnswer(
          (_) async => const Result.failure(RejectedFailure('The event has ended.')),
        );
      },
      build: () => CheckInBloc(checkIn: checkIn),
      act: (bloc) => bloc.add(const CheckInRequested(eventId: 'e0', code: 'TK1')),
      expect: () => const [
        CheckInState(status: CheckInStatus.checking),
        CheckInState(status: CheckInStatus.failure, errorMessage: 'The event has ended.'),
        CheckInState(),
      ],
    );
  });

  group('DoorSaleBloc', () {
    late _MockSellAtDoor sellAtDoor;

    setUp(() => sellAtDoor = _MockSellAtDoor());

    DoorSaleBloc build({int left = 50}) {
      return DoorSaleBloc(sellAtDoor: sellAtDoor, event: event, ticketsLeft: left);
    }

    test('at most 8 tickets per sale', () async {
      final bloc = build();
      for (var i = 0; i < 9; i++) {
        bloc.add(const DoorSaleQuantityIncreased('5K'));
      }
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.count, 8);
      await bloc.close();
    });

    test('never more than the tickets left', () async {
      final notices = <String>[];
      final bloc = build(left: 2);
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      for (var i = 0; i < 3; i++) {
        bloc.add(const DoorSaleQuantityIncreased('10K'));
      }
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.count, 2);
      expect(bloc.state.totalCents, 3600);
      expect(notices, ['Only 2 left']);
      await subscription.cancel();
      await bloc.close();
    });

    test('needs a ticket and a valid phone number before payment', () async {
      final bloc = build()..add(const DoorSaleCheckoutRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.step, DoorSaleStep.selecting);

      bloc
        ..add(const DoorSaleQuantityIncreased('5K'))
        ..add(const DoorSalePhoneChanged('012 777 888'))
        ..add(const DoorSaleCheckoutRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.step, DoorSaleStep.payment);
      await bloc.close();
    });

    test('sends the sale with the buyer phone and moves to done', () async {
      const sale = Booking(
        id: 'TK12345678',
        eventId: 'e0',
        buyerName: 'Walk-in guest',
        phone: '+855 12 777 888',
        lines: [BookingLine(ticketType: '5K', quantity: 1)],
        totalCents: 1200,
        payment: PaymentMethod.abaKhqr,
        channel: SalesChannel.door,
        status: BookingStatus.open,
      );
      when(() => sellAtDoor(any())).thenAnswer((_) async => const Result.success(sale));

      final bloc = build()
        ..add(const DoorSaleQuantityIncreased('5K'))
        ..add(const DoorSalePhoneChanged('012 777 888'))
        ..add(const DoorSalePaymentChanged(PaymentMethod.abaKhqr))
        ..add(const DoorSaleCheckoutRequested())
        ..add(const DoorSalePaymentConfirmed());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.step, DoorSaleStep.completed);
      expect(bloc.state.sale, sale);
      verify(
        () => sellAtDoor(
          const DoorSaleRequest(
            eventId: 'e0',
            lines: [BookingLine(ticketType: '5K', quantity: 1)],
            buyerPhone: '+85512777888',
            payment: PaymentMethod.abaKhqr,
          ),
        ),
      ).called(1);
      await bloc.close();
    });
  });

  group('CancelBookingBloc', () {
    late _MockCancelBooking cancel;
    const bookingId = 'TK12345678';

    setUp(() => cancel = _MockCancelBooking());

    blocTest<CancelBookingBloc, CancelBookingState>(
      'asks for a reason first and does not call the server',
      build: () => CancelBookingBloc(cancelBooking: cancel, bookingId: bookingId),
      act: (bloc) => bloc.add(const CancelConfirmed()),
      expect: () => const [CancelBookingState(errorMessage: 'Choose why you are cancelling.')],
      verify: (_) => verifyNever(() => cancel(any())),
    );

    blocTest<CancelBookingBloc, CancelBookingState>(
      'cancels with the chosen reason',
      setUp: () => when(() => cancel(any())).thenAnswer((_) async => Result.success(_booking)),
      build: () => CancelBookingBloc(cancelBooking: cancel, bookingId: bookingId),
      act: (bloc) => bloc
        ..add(const CancelReasonChosen(CancelReason.soldByMistake))
        ..add(const CancelConfirmed()),
      expect: () => const [
        CancelBookingState(reason: CancelReason.soldByMistake),
        CancelBookingState(reason: CancelReason.soldByMistake, submitting: true),
        CancelBookingState(reason: CancelReason.soldByMistake, cancelled: true),
      ],
      verify: (_) => verify(
        () => cancel(const CancelBookingParams(bookingId: bookingId, reason: CancelReason.soldByMistake)),
      ).called(1),
    );

    blocTest<CancelBookingBloc, CancelBookingState>(
      'shows the refusal and lets the owner try again',
      setUp: () => when(() => cancel(any())).thenAnswer(
        (_) async => const Result.failure(RejectedFailure('The event has ended.')),
      ),
      build: () => CancelBookingBloc(cancelBooking: cancel, bookingId: bookingId),
      act: (bloc) => bloc
        ..add(const CancelReasonChosen(CancelReason.other))
        ..add(const CancelConfirmed()),
      expect: () => const [
        CancelBookingState(reason: CancelReason.other),
        CancelBookingState(reason: CancelReason.other, submitting: true),
        CancelBookingState(reason: CancelReason.other, errorMessage: 'The event has ended.'),
      ],
    );
  });

  group('CancelBookingBloc while busy and on reopening', () {
    late _MockCancelBooking cancel;
    const bookingId = 'TK12345678';

    setUp(() => cancel = _MockCancelBooking());

    blocTest<CancelBookingBloc, CancelBookingState>(
      'changing the reason while the request is on its way changes nothing and sends one request',
      setUp: () => when(() => cancel(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return Result.success(_booking);
      }),
      build: () => CancelBookingBloc(cancelBooking: cancel, bookingId: bookingId),
      act: (bloc) async {
        bloc
          ..add(const CancelReasonChosen(CancelReason.buyerAsked))
          ..add(const CancelConfirmed());
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const CancelReasonChosen(CancelReason.other))
          ..add(const CancelConfirmed());
      },
      wait: const Duration(milliseconds: 60),
      expect: () => const [
        CancelBookingState(reason: CancelReason.buyerAsked),
        CancelBookingState(reason: CancelReason.buyerAsked, submitting: true),
        CancelBookingState(reason: CancelReason.buyerAsked, cancelled: true),
      ],
      verify: (_) => verify(
        () => cancel(const CancelBookingParams(bookingId: bookingId, reason: CancelReason.buyerAsked)),
      ).called(1),
    );

    blocTest<CancelBookingBloc, CancelBookingState>(
      'an error from an earlier try is gone when the sheet is opened again',
      setUp: () => when(() => cancel(any())).thenAnswer(
        (_) async => const Result.failure(RejectedFailure('The event has ended.')),
      ),
      build: () => CancelBookingBloc(cancelBooking: cancel, bookingId: bookingId),
      act: (bloc) async {
        bloc
          ..add(const CancelReasonChosen(CancelReason.other))
          ..add(const CancelConfirmed());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CancelSheetOpened());
      },
      expect: () => const [
        CancelBookingState(reason: CancelReason.other),
        CancelBookingState(reason: CancelReason.other, submitting: true),
        CancelBookingState(reason: CancelReason.other, errorMessage: 'The event has ended.'),
        CancelBookingState(reason: CancelReason.other),
      ],
    );
  });

  group('CreateEventBloc', () {
    late _MockPublishEvent publish;

    setUp(() => publish = _MockPublishEvent());

    test('explains the first thing that is missing and does not publish', () async {
      final notices = <String>[];
      final bloc = CreateEventBloc(publishEvent: publish, coverPhotos: _unusedPhotos);
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc
        ..add(const CreateEventSubmitted())
        ..add(const CreateEventNameChanged('Night Run'))
        ..add(const CreateEventSubmitted());
      await Future<void>.delayed(Duration.zero);

      expect(notices, ['Enter the event name', 'Choose the date and start time']);
      verifyNever(() => publish(any()));
      await subscription.cancel();
      await bloc.close();
    });

    test('allows 1 to 6 ticket types', () async {
      final bloc = CreateEventBloc(publishEvent: publish, coverPhotos: _unusedPhotos);
      for (var i = 0; i < 7; i++) {
        bloc.add(const CreateEventTicketTypeAdded());
      }
      for (var id = 0; id < 10; id++) {
        bloc.add(CreateEventTicketTypeRemoved(id));
      }
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.ticketTypes, hasLength(1));
      await bloc.close();
    });

    test('publishes a complete event; price may be empty for free', () async {
      when(() => publish(any())).thenAnswer((_) async => Result.success(event));
      final bloc = CreateEventBloc(publishEvent: publish, coverPhotos: _unusedPhotos)
        ..add(const CreateEventNameChanged(' Night Run '))
        ..add(CreateEventDateChanged(DateTime(2026, 12, 1)))
        ..add(const CreateEventTimeChanged(hour: 18, minute: 30))
        ..add(const CreateEventVenueChanged('Riverside'))
        ..add(const CreateEventTicketTypeChanged(0, name: '5K', price: '', quantity: '100'))
        ..add(const CreateEventTicketTypeAdded())
        ..add(const CreateEventTicketTypeChanged(1, name: '10K', price: '12.5', quantity: '50'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.capacity, 150);

      // Everything is filled in except the kind: not ready yet.
      expect(bloc.state.isValid, isFalse);
      expect(bloc.state.problem, 'Choose what kind of event it is');
      bloc.add(const CreateEventKindChanged(EventKind.marathon));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isValid, isTrue);

      bloc.add(const CreateEventSubmitted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, CreateEventStatus.published);
      verify(
        () => publish(
          EventDraft(
            name: 'Night Run',
            startsAt: DateTime(2026, 12, 1, 18, 30),
            venue: 'Riverside',
            kind: EventKind.marathon,
            ticketTypes: const [
              TicketType(name: '5K', priceCents: 0, quantity: 100),
              TicketType(name: '10K', priceCents: 1250, quantity: 50),
            ],
          ),
        ),
      ).called(1);
      await bloc.close();
    });
  });

  group('CreateTripBloc', () {
    late _MockPublishBusTrip publish;

    setUp(() => publish = _MockPublishBusTrip());

    CreateTripBloc filledIn() => CreateTripBloc(publishBusTrip: publish, coverPhotos: _unusedPhotos)
      ..add(const CreateTripOriginChanged(' Phnom Penh '))
      ..add(const CreateTripDestinationChanged('Siem Reap'))
      ..add(CreateTripDateChanged(DateTime(2026, 12, 5)))
      ..add(const CreateTripTimeChanged(hour: 8, minute: 45))
      ..add(const CreateTripDurationChanged('6'))
      ..add(const CreateTripBoardingPointChanged('Giant Ibis Terminal'));

    test('explains the first thing that is missing and does not publish', () async {
      final notices = <String>[];
      final bloc = CreateTripBloc(publishBusTrip: publish, coverPhotos: _unusedPhotos);
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc
        ..add(const CreateTripSubmitted())
        ..add(const CreateTripOriginChanged('Kampot'))
        ..add(const CreateTripDestinationChanged('kampot'))
        ..add(const CreateTripSubmitted());
      await Future<void>.delayed(Duration.zero);

      expect(notices, [
        'Enter where the trip starts',
        'The trip must go somewhere other than where it starts',
      ]);
      verifyNever(() => publish(any()));
      await subscription.cancel();
      await bloc.close();
    });

    test('reads the journey in hours, with a comma or a point, within 10 minutes to 24 hours', () async {
      final bloc = CreateTripBloc(publishBusTrip: publish, coverPhotos: _unusedPhotos);
      Future<int?> minutesFor(String hours) async {
        bloc.add(CreateTripDurationChanged(hours));
        await Future<void>.delayed(Duration.zero);
        return bloc.state.durationMinutes;
      }

      expect(await minutesFor('6'), 360);
      expect(await minutesFor('3,5'), 210);
      expect(await minutesFor('0.1'), isNull);
      expect(await minutesFor('25'), isNull);
      expect(await minutesFor(''), isNull);
      await bloc.close();
    });

    test('publishes a complete trip; the price may be empty for free; things on board keep their order', () async {
      final trip = Event(
        id: 'e9',
        name: 'Phnom Penh to Siem Reap',
        kind: EventKind.bus,
        startsAt: DateTime(2026, 12, 5, 8, 45),
        venue: 'Giant Ibis Terminal',
        ticketTypes: const [TicketType(name: 'Seat', priceCents: 0, quantity: 40)],
        approved: false,
      );
      when(() => publish(any())).thenAnswer((_) async => Result.success(trip));
      final bloc = filledIn()
        ..add(const CreateTripAmenityToggled('Snack'))
        ..add(const CreateTripAmenityToggled('Wi-Fi'))
        ..add(const CreateTripAmenityToggled('Snack'))
        ..add(const CreateTripAmenityToggled('A/C'))
        ..add(const CreateTripAboutChanged(' Two days at Angkor '));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isValid, isTrue);
      expect(bloc.state.coach, CoachType.seater);

      bloc.add(const CreateTripSubmitted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, CreateTripStatus.published);
      expect(bloc.state.notice, contains('sent to Pin for approval'));
      verify(
        () => publish(
          TripDraft(
            origin: 'Phnom Penh',
            destination: 'Siem Reap',
            startsAt: DateTime(2026, 12, 5, 8, 45),
            durationMinutes: 360,
            coach: CoachType.seater,
            priceCents: 0,
            boardingPoint: 'Giant Ibis Terminal',
            about: 'Two days at Angkor',
            amenities: const ['Wi-Fi', 'A/C'],
          ),
        ),
      ).called(1);
      await bloc.close();
    });

    test('a refusal from the server is shown and the form stays open', () async {
      when(() => publish(any())).thenAnswer(
        (_) async => const Result.failure(RejectedFailure('Only bus companies publish bus trips.')),
      );
      final notices = <String>[];
      final bloc = filledIn();
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc.add(const CreateTripSubmitted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notices, ['Only bus companies publish bus trips.']);
      expect(bloc.state.status, CreateTripStatus.editing);
      await subscription.cancel();
      await bloc.close();
    });
  });

  group('CreatePlaceBloc', () {
    late _MockPublishPlace publish;

    setUp(() => publish = _MockPublishPlace());

    CreatePlaceBloc filledIn() => CreatePlaceBloc(publishPlace: publish, coverPhotos: _unusedPhotos)
      ..add(const CreatePlaceNameChanged(' Garden City Water Park '))
      ..add(const CreatePlaceVenueChanged('Garden City'))
      ..add(const CreatePlaceTicketChanged(0, name: ' Adult '))
      ..add(const CreatePlaceTicketChanged(0, price: '10', limit: '300'));

    test('explains the first thing that is missing and does not publish', () async {
      final notices = <String>[];
      final bloc = CreatePlaceBloc(publishPlace: publish, coverPhotos: _unusedPhotos);
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc
        ..add(const CreatePlaceSubmitted())
        ..add(const CreatePlaceNameChanged('Garden City'))
        ..add(const CreatePlaceSubmitted())
        ..add(const CreatePlaceVenueChanged('Garden City'))
        ..add(const CreatePlaceSubmitted());
      await Future<void>.delayed(Duration.zero);

      expect(notices, [
        'Enter the name of the place',
        'Enter the venue',
        'Give every ticket type a name; a daily limit is at least 1',
      ]);
      verifyNever(() => publish(any()));
      await subscription.cancel();
      await bloc.close();
    });

    test('a daily limit is at least 1 and may be left empty for no limit; names differ', () async {
      final bloc = filledIn();
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isValid, isTrue);

      bloc.add(const CreatePlaceTicketChanged(0, limit: '0'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isValid, isFalse);

      bloc
        ..add(const CreatePlaceTicketChanged(0, limit: ''))
        ..add(const CreatePlaceTicketAdded())
        ..add(const CreatePlaceTicketChanged(1, name: 'ADULT'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.tickets.first.dailyLimit, isNull);
      expect(bloc.state.problem, 'Each ticket type needs a different name');
      await bloc.close();
    });

    test('keeps one to six ticket types', () async {
      final bloc = filledIn();
      for (var i = 0; i < 7; i++) {
        bloc.add(const CreatePlaceTicketAdded());
      }
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.tickets, hasLength(6));

      bloc.add(CreatePlaceTicketRemoved(bloc.state.tickets.last.id));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.tickets, hasLength(5));

      final single = CreatePlaceBloc(publishPlace: publish, coverPhotos: _unusedPhotos)..add(const CreatePlaceTicketRemoved(0));
      await Future<void>.delayed(Duration.zero);
      expect(single.state.tickets, hasLength(1));
      await bloc.close();
      await single.close();
    });

    test('publishes a complete place; the price may be empty for free', () async {
      final place = Event(
        id: 'e9',
        name: 'Garden City Water Park',
        kind: EventKind.admission,
        startsAt: DateTime(2026, 12, 5),
        venue: 'Garden City',
        ticketTypes: const [TicketType(name: 'Adult', priceCents: 1000, quantity: 300)],
        approved: false,
      );
      when(() => publish(any())).thenAnswer((_) async => Result.success(place));
      final bloc = filledIn()
        ..add(const CreatePlaceAddressChanged(' Chroy Changvar '))
        ..add(const CreatePlaceAboutChanged(' Slides and a wave pool '))
        ..add(const CreatePlacePolicyChanged('Refundable up to the day before'))
        ..add(const CreatePlaceTicketAdded())
        ..add(const CreatePlaceTicketChanged(1, name: 'Child', description: 'Under 12'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CreatePlaceSubmitted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, CreatePlaceStatus.published);
      expect(bloc.state.notice, contains('sent to Pin for approval'));
      verify(
        () => publish(
          const PlaceDraft(
            name: 'Garden City Water Park',
            venue: 'Garden City',
            venueDetail: 'Chroy Changvar',
            about: 'Slides and a wave pool',
            policy: 'Refundable up to the day before',
            tickets: [
              PlaceTicketDraft(name: 'Adult', priceCents: 1000, dailyLimit: 300),
              PlaceTicketDraft(name: 'Child', priceCents: 0, description: 'Under 12'),
            ],
          ),
        ),
      ).called(1);
      await bloc.close();
    });

    test('a refusal from the server is shown and the form stays open', () async {
      when(() => publish(any())).thenAnswer(
        (_) async => const Result.failure(RejectedFailure('Only admission businesses publish places.')),
      );
      final notices = <String>[];
      final bloc = filledIn();
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc.add(const CreatePlaceSubmitted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notices, ['Only admission businesses publish places.']);
      expect(bloc.state.status, CreatePlaceStatus.editing);
      await subscription.cancel();
      await bloc.close();
    });
  });

  group('CreateScreeningBloc', () {
    late _MockPublishScreening publish;

    setUp(() => publish = _MockPublishScreening());

    CreateScreeningBloc filledIn() => CreateScreeningBloc(publishScreening: publish, coverPhotos: _unusedPhotos)
      ..add(const CreateScreeningFilmChanged(' Skyline Run '))
      ..add(const CreateScreeningRuntimeChanged('128'))
      ..add(const CreateScreeningTheatreChanged('Legend Cinema, Aeon Mall'))
      ..add(const CreateScreeningHallChanged(' Hall 2 '))
      ..add(CreateScreeningDateChanged(DateTime(2026, 12, 5)))
      ..add(const CreateScreeningTimeChanged(hour: 19, minute: 30));

    test('explains the first thing that is missing and does not publish', () async {
      final notices = <String>[];
      final bloc = CreateScreeningBloc(publishScreening: publish, coverPhotos: _unusedPhotos);
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc
        ..add(const CreateScreeningSubmitted())
        ..add(const CreateScreeningFilmChanged('Skyline Run'))
        ..add(const CreateScreeningSubmitted())
        ..add(const CreateScreeningRuntimeChanged('128'))
        ..add(const CreateScreeningSubmitted());
      await Future<void>.delayed(Duration.zero);

      expect(notices, [
        "Enter the film's title",
        'Enter how long the film runs, in minutes',
        'Enter the cinema',
      ]);
      verifyNever(() => publish(any()));
      await subscription.cancel();
      await bloc.close();
    });

    test('reads the running time in minutes, from 10 minutes to 10 hours', () async {
      final bloc = CreateScreeningBloc(publishScreening: publish, coverPhotos: _unusedPhotos);
      Future<int?> minutesFor(String text) async {
        bloc.add(CreateScreeningRuntimeChanged(text));
        await Future<void>.delayed(Duration.zero);
        return bloc.state.runtimeMinutes;
      }

      expect(await minutesFor('112'), 112);
      expect(await minutesFor('9'), isNull);
      expect(await minutesFor('601'), isNull);
      expect(await minutesFor(''), isNull);
      await bloc.close();
    });

    test('choosing the rating again takes it back', () async {
      final bloc = CreateScreeningBloc(publishScreening: publish, coverPhotos: _unusedPhotos)
        ..add(const CreateScreeningRatingChosen('PG'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.rating, 'PG');

      bloc.add(const CreateScreeningRatingChosen('PG'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.rating, isEmpty);
      await bloc.close();
    });

    test('publishes a complete screening; the price may be empty for free', () async {
      final screening = Event(
        id: 'e9',
        name: 'Skyline Run',
        kind: EventKind.cinema,
        startsAt: DateTime(2026, 12, 5, 19, 30),
        venue: 'Legend Cinema, Aeon Mall',
        ticketTypes: const [TicketType(name: 'Seat', priceCents: 0, quantity: 80)],
        approved: false,
      );
      when(() => publish(any())).thenAnswer((_) async => Result.success(screening));
      final bloc = filledIn()
        ..add(const CreateScreeningRatingChosen('PG-13'))
        ..add(const CreateScreeningGenreChanged(' Action '))
        ..add(const CreateScreeningAboutChanged(' A courier crosses a city '))
        ..add(const CreateScreeningAreaChanged('Aeon Mall, Phnom Penh'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isValid, isTrue);
      expect(bloc.state.size, HallSize.standard);

      bloc.add(const CreateScreeningSubmitted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, CreateScreeningStatus.published);
      expect(bloc.state.notice, contains('sent to Pin for approval'));
      verify(
        () => publish(
          ScreeningDraft(
            filmTitle: 'Skyline Run',
            runtimeMinutes: 128,
            theatre: 'Legend Cinema, Aeon Mall',
            theatreArea: 'Aeon Mall, Phnom Penh',
            hall: 'Hall 2',
            hallSize: HallSize.standard,
            startsAt: DateTime(2026, 12, 5, 19, 30),
            priceCents: 0,
            rating: 'PG-13',
            genre: 'Action',
            about: 'A courier crosses a city',
          ),
        ),
      ).called(1);
      await bloc.close();
    });

    test('a refusal from the server is shown and the form stays open', () async {
      when(() => publish(any())).thenAnswer(
        (_) async => const Result.failure(RejectedFailure('Only cinemas publish screenings.')),
      );
      final notices = <String>[];
      final bloc = filledIn();
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc.add(const CreateScreeningSubmitted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notices, ['Only cinemas publish screenings.']);
      expect(bloc.state.status, CreateScreeningStatus.editing);
      await subscription.cancel();
      await bloc.close();
    });
  });
}
