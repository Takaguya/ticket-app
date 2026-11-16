import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/storage/key_value_store.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:user/features/auth/data/models/auth_session_model.dart';
import 'package:user/features/auth/data/models/pin_user_model.dart';
import 'package:user/features/auth/domain/entities/gender.dart';
import 'package:user/features/booking/data/repositories/mock_booking_repository.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/domain/entities/order.dart';
import 'package:user/features/booking/domain/entities/runner_details.dart';
import 'package:user/features/booking/domain/usecases/get_saved_runner.dart';
import 'package:user/features/booking/presentation/bloc/runner_details/runner_details_bloc.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/mock_backend/mock_bookings.dart';
import 'package:user/mock_backend/mock_catalog.dart';

void main() {
  // Sunday 15 Nov 2026, 08:00.
  final clock = FixedClock(DateTime(2026, 11, 15, 8));
  final catalog = MockCatalog(clock: clock);
  final race = catalog.byId('ev2')! as EventListing;
  final dara = PinUserModel(
    id: 'u_2',
    name: 'Dara Pich',
    phone: '+85512888999',
    gender: Gender.male,
    dateOfBirth: DateTime(1990, 1, 1),
  );
  // What Dara saved at an earlier race.
  const saved = RunnerDetails(
    name: 'Dara Pich',
    phone: '+85512888999',
    gender: Gender.male,
    age: 36,
    nationality: 'Cambodian',
    emergencyName: 'Srey Pich',
    emergencyPhone: '+85517555444',
    shirtSize: ShirtSize.l,
  );

  late MockBookings bookings;
  late MockBookingRepository repository;

  setUp(() async {
    final session = AuthLocalDataSource(InMemoryKeyValueStore());
    await session.saveSession(AuthSessionModel(accessToken: 'test', user: dara));
    bookings = MockBookings(catalog: catalog);
    repository = MockBookingRepository(
      bookings: bookings,
      session: session,
      latency: Duration.zero,
      paymentLatency: Duration.zero,
    );
  });

  Future<RunnerDetailsBloc> started() async {
    final bloc = RunnerDetailsBloc(
      getSavedRunner: GetSavedRunner(repository),
      clock: clock,
      account: dara.toEntity(),
    )..add(const RunnerDetailsStarted());
    await bloc.stream.firstWhere((state) => state.status == RunnerDetailsStatus.ready);
    return bloc;
  }

  /// Lets the bloc handle the events added so far.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('without saved details, the form starts from the account and says what is missing', () async {
    final bloc = await started();
    final state = bloc.state;

    expect(state.name, 'Dara Pich');
    expect(state.phone, '12 888 999');
    expect(state.gender, Gender.male);
    // Born 1 Jan 1990.
    expect(state.age, '36');
    expect(state.filledFromSaved, isFalse);
    expect(state.problem, 'Enter the nationality');
    expect(state.runner, isNull);

    bloc.add(const RunnerTextChanged(RunnerField.age, '4'));
    await settle();
    expect(bloc.state.problem, 'Enter an age from 5 to 99');
    await bloc.close();
  });

  test('details saved at an earlier race fill the rest of the form', () async {
    bookings.place(
      dara.toEntity(),
      Order(
        request: EventRequest(event: race, quantities: {race.tiers.first: 1}).withRunner(saved),
        paymentMethod: PaymentMethod.card,
        saveRunner: true,
      ),
    );

    final bloc = await started();

    expect(bloc.state.filledFromSaved, isTrue);
    expect(bloc.state.emergencyPhone, '17 555 444');
    expect(bloc.state.problem, isNull);
    expect(bloc.state.runner, saved);
    expect(bloc.state.savesToAccount, isTrue);
    await bloc.close();
  });

  test('someone else starts empty, with the account holder to call, and is never saved', () async {
    final bloc = await started();
    final before = bloc.state.formVersion;

    bloc.add(const RunnerForSomeoneElseChanged(true));
    await settle();
    expect(bloc.state.name, isEmpty);
    expect(bloc.state.gender, isNull);
    expect(bloc.state.emergencyName, 'Dara Pich');
    expect(bloc.state.emergencyPhone, '12 888 999');
    expect(bloc.state.formVersion, before + 1);

    bloc.add(const RunnerSaveChanged(true));
    await settle();
    expect(bloc.state.savesToAccount, isFalse);

    // Back to "Myself": the account's details again.
    bloc.add(const RunnerForSomeoneElseChanged(false));
    await settle();
    expect(bloc.state.name, 'Dara Pich');
    expect(bloc.state.savesToAccount, isTrue);
    expect(bloc.state.formVersion, before + 2);
    await bloc.close();
  });
}
