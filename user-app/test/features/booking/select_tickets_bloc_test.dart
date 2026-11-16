import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user/core/error/failure.dart';
import 'package:user/core/result/result.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/presentation/bloc/select_tickets/select_tickets_bloc.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/features/catalog/domain/entities/place_availability.dart';
import 'package:user/features/catalog/domain/usecases/get_place_availability.dart';
import 'package:user/mock_backend/mock_catalog.dart';

class _MockGetPlaceAvailability extends Mock implements GetPlaceAvailability {}

void main() {
  setUpAll(() => registerFallbackValue(PlaceDayQuery(placeId: '', day: DateTime(2026))));

  // Sunday 15 Nov 2026, 08:00.
  final clock = FixedClock(DateTime(2026, 11, 15, 8));
  final catalog = MockCatalog(clock: clock);
  final rock = catalog.byId('ev1')! as EventListing;
  final race = catalog.byId('ev2')! as EventListing;
  final angkor = catalog.byId('ad1')! as AdmissionListing;

  blocTest<SelectTicketsBloc, SelectTicketsState>(
    'at most 8 tickets in one booking',
    build: () => SelectTicketsBloc(clock: clock, listing: rock),
    act: (bloc) {
      for (var i = 0; i < 9; i++) {
        bloc.add(SelectTicketsAdded(rock.tiers.first));
      }
    },
    verify: (bloc) {
      expect(bloc.state.ticketCount, 8);
      expect(bloc.state.totalCents, 8 * 1500);
    },
  );

  blocTest<SelectTicketsBloc, SelectTicketsState>(
    'says so when the limit is reached',
    build: () => SelectTicketsBloc(clock: clock, listing: rock),
    seed: () => SelectTicketsState(listing: rock, quantities: {rock.tiers.first: 8}),
    act: (bloc) => bloc.add(SelectTicketsAdded(rock.tiers.last)),
    expect: () => [
      isA<SelectTicketsState>().having((s) => s.notice, 'notice', 'Maximum 8 tickets per booking'),
      isA<SelectTicketsState>().having((s) => s.notice, 'notice', isNull),
    ],
  );

  blocTest<SelectTicketsBloc, SelectTicketsState>(
    'a race takes one runner: "+" on another distance moves the entry',
    build: () => SelectTicketsBloc(clock: clock, listing: race),
    act: (bloc) {
      bloc
        ..add(SelectTicketsAdded(race.tiers.first))
        ..add(SelectTicketsAdded(race.tiers.last))
        ..add(SelectTicketsAdded(race.tiers.last));
    },
    verify: (bloc) {
      expect(bloc.state.quantities, {race.tiers.last: 1});
      expect(bloc.state.request, isA<EventRequest>());
    },
  );

  blocTest<SelectTicketsBloc, SelectTicketsState>(
    'a place is booked for a day: today, unless another day is chosen',
    build: () => SelectTicketsBloc(clock: clock, listing: angkor),
    act: (bloc) {
      bloc
        ..add(SelectTicketsAdded(angkor.tiers.first))
        ..add(SelectTicketsAdded(angkor.tiers.last))
        ..add(SelectTicketsDayChosen(DateTime(2026, 11, 20, 15, 30)));
    },
    verify: (bloc) {
      final state = bloc.state;
      expect(state.days, hasLength(SelectTicketsBloc.admissionDays));
      expect(state.days.first, DateTime(2026, 11, 15));
      final request = state.request! as AdmissionRequest;
      expect(request.day, DateTime(2026, 11, 20));
      // An adult at $37 and a child for free.
      expect(request.ticketCount, 2);
      expect(request.subtotalCents, 3700);
    },
  );

  group('a place with a limit per day', () {
    late _MockGetPlaceAvailability getAvailability;
    final adult = angkor.tiers.first;
    final child = angkor.tiers.last;

    PlaceAvailability only(Map<String, int> left) => PlaceAvailability(left);

    setUp(() {
      getAvailability = _MockGetPlaceAvailability();
      // Today: 2 adult tickets left; any other day nothing is limited.
      when(() => getAvailability(any())).thenAnswer((invocation) async {
        final query = invocation.positionalArguments.single as PlaceDayQuery;
        return Result.success(
          query.day == DateTime(2026, 11, 15) ? only({'Adult': 2}) : PlaceAvailability.unlimited,
        );
      });
    });

    SelectTicketsBloc build() =>
        SelectTicketsBloc(clock: clock, listing: angkor, getPlaceAvailability: getAvailability);

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('asks what is left of today when it opens, and says what is left in its state', () async {
      final bloc = build()..add(const SelectTicketsStarted());
      await settle();

      verify(() => getAvailability(PlaceDayQuery(placeId: angkor.id, day: DateTime(2026, 11, 15)))).called(1);
      expect(bloc.state.availability.leftOf('Adult'), 2);
      expect(bloc.state.availability.leftOf('Child'), isNull);
      await bloc.close();
    });

    test('no more of a kind than is left: a notice says how many, and it is sold out at 0', () async {
      final bloc = build()..add(const SelectTicketsStarted());
      await settle();
      final notices = <String>[];
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      for (var i = 0; i < 3; i++) {
        bloc.add(SelectTicketsAdded(adult));
      }
      // A kind with no limit keeps going.
      bloc.add(SelectTicketsAdded(child));
      await settle();

      expect(bloc.state.quantityOf(adult), 2);
      expect(bloc.state.quantityOf(child), 1);
      expect(notices, ['Only 2 Adult left on this day']);

      bloc.add(SelectTicketsDayChosen(DateTime(2026, 11, 16)));
      await settle();
      expect(bloc.state.availability, PlaceAvailability.unlimited);
      await subscription.cancel();
      await bloc.close();
    });

    test('a sold-out kind cannot be added', () async {
      when(() => getAvailability(any())).thenAnswer((_) async => Result.success(only({'Adult': 0})));
      final bloc = build()..add(const SelectTicketsStarted());
      await settle();
      final notices = <String>[];
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc.add(SelectTicketsAdded(adult));
      await settle();

      expect(bloc.state.quantityOf(adult), 0);
      expect(notices, ['Adult is sold out on this day']);
      await subscription.cancel();
      await bloc.close();
    });

    test('choosing another day with fewer tickets left lowers what was chosen, and says so', () async {
      final bloc = build();
      bloc
        ..add(SelectTicketsDayChosen(DateTime(2026, 11, 16)))
        ..add(SelectTicketsAdded(adult))
        ..add(SelectTicketsAdded(adult))
        ..add(SelectTicketsAdded(adult));
      await settle();
      expect(bloc.state.quantityOf(adult), 3);
      final notices = <String>[];
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      bloc.add(SelectTicketsDayChosen(DateTime(2026, 11, 15)));
      await settle();

      expect(bloc.state.quantityOf(adult), 2);
      expect(notices, ['Fewer tickets are left on this day, so your choice was changed']);
      await subscription.cancel();
      await bloc.close();
    });

    test('a kind taken back to 0 is not "changed" by another day that has room for it', () async {
      final bloc = build()..add(SelectTicketsDayChosen(DateTime(2026, 11, 16)));
      await settle();
      bloc
        ..add(SelectTicketsAdded(child))
        ..add(SelectTicketsAdded(adult))
        ..add(SelectTicketsRemoved(adult));
      await settle();
      expect(bloc.state.quantityOf(adult), 0);
      expect(bloc.state.quantityOf(child), 1);
      final notices = <String>[];
      final subscription = bloc.stream.listen((s) {
        if (s.notice != null) notices.add(s.notice!);
      });

      // Today has 2 adults left: nothing chosen goes past that, so nothing is lowered.
      bloc.add(SelectTicketsDayChosen(DateTime(2026, 11, 15)));
      await settle();

      expect(bloc.state.quantityOf(child), 1);
      expect(notices, isEmpty);
      await subscription.cancel();
      await bloc.close();
    });

    test('when the answer cannot be had nothing is limited here; the server still decides', () async {
      when(() => getAvailability(any())).thenAnswer((_) async => const Result.failure(NetworkFailure('Offline')));
      final bloc = build()..add(const SelectTicketsStarted());
      await settle();

      bloc.add(SelectTicketsAdded(adult));
      await settle();

      expect(bloc.state.availability, PlaceAvailability.unlimited);
      expect(bloc.state.quantityOf(adult), 1);
      await bloc.close();
    });
  });

  test('nothing to pay for until a ticket is chosen', () {
    final bloc = SelectTicketsBloc(clock: clock, listing: rock);
    expect(bloc.state.request, isNull);
    expect(bloc.state.tiers, rock.tiers);
    bloc.close();
  });
}
