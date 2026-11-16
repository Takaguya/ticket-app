import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../core/config/app_config.dart';
import '../../core/media/photo_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/services/file_sharer.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/usecase/usecase.dart';
import '../../core/utils/ticker.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_mock_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/join_team.dart';
import '../../features/auth/domain/usecases/refresh_session.dart';
import '../../features/auth/domain/usecases/register_business.dart';
import '../../features/auth/domain/usecases/request_otp.dart';
import '../../features/auth/domain/usecases/restore_session.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/domain/usecases/watch_session.dart';
import '../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../features/auth/presentation/bloc/join_team/join_team_bloc.dart';
import '../../features/auth/presentation/bloc/login/login_bloc.dart';
import '../../features/auth/presentation/bloc/otp/otp_bloc.dart';
import '../../features/auth/presentation/bloc/register_business/register_business_bloc.dart';
import '../../features/bookings/data/datasources/bookings_api_data_source.dart';
import '../../features/bookings/data/repositories/api_bookings_repository.dart';
import '../../features/bookings/data/repositories/mock_bookings_repository.dart';
import '../../features/bookings/domain/repositories/bookings_repository.dart';
import '../../features/bookings/domain/usecases/cancel_booking.dart';
import '../../features/bookings/domain/usecases/check_in_booking.dart';
import '../../features/bookings/domain/usecases/sell_at_door.dart';
import '../../features/bookings/presentation/bloc/bookings_filter/bookings_filter_bloc.dart';
import '../../features/bookings/presentation/bloc/cancel_booking/cancel_booking_bloc.dart';
import '../../features/bookings/presentation/bloc/check_in/check_in_bloc.dart';
import '../../features/dashboard/domain/usecases/watch_business_snapshot.dart';
import '../../features/dashboard/presentation/bloc/business/business_bloc.dart';
import '../../features/door_sale/presentation/bloc/door_sale_bloc.dart';
import '../../features/events/data/datasources/events_api_data_source.dart';
import '../../features/events/data/repositories/api_events_repository.dart';
import '../../features/events/data/repositories/mock_events_repository.dart';
import '../../features/events/domain/entities/event.dart';
import '../../features/events/domain/repositories/events_repository.dart';
import '../../features/events/domain/usecases/publish_event.dart';
import '../../features/events/domain/usecases/publish_bus_trip.dart';
import '../../features/events/domain/usecases/publish_place.dart';
import '../../features/events/domain/usecases/publish_screening.dart';
import '../../features/events/domain/usecases/remove_event_image.dart';
import '../../features/events/domain/usecases/set_event_image.dart';
import '../../features/events/presentation/bloc/cover_photos.dart';
import '../../features/events/presentation/bloc/create_event_bloc.dart';
import '../../features/events/presentation/bloc/create_place_bloc.dart';
import '../../features/events/presentation/bloc/create_screening_bloc.dart';
import '../../features/events/presentation/bloc/create_trip_bloc.dart';
import '../../features/events/presentation/bloc/event_picture_cubit.dart';
import '../../features/payouts/data/api_payouts_repository.dart';
import '../../features/payouts/data/mock_payouts_repository.dart';
import '../../features/payouts/data/payouts_api_data_source.dart';
import '../../features/payouts/domain/repositories/payouts_repository.dart';
import '../../features/payouts/domain/usecases/get_payouts.dart';
import '../../features/payouts/presentation/bloc/payouts_bloc.dart';
import '../../features/staff/data/datasources/staff_api_data_source.dart';
import '../../features/staff/data/repositories/api_staff_repository.dart';
import '../../features/staff/data/repositories/mock_staff_repository.dart';
import '../../features/staff/domain/repositories/staff_repository.dart';
import '../../features/staff/domain/usecases/regenerate_join_code.dart';
import '../../features/staff/domain/usecases/remove_staff_member.dart';
import '../../features/staff/domain/usecases/watch_team.dart';
import '../../features/staff/presentation/bloc/staff_bloc.dart';
import '../../mock_backend/mock_merchant_backend.dart';
import '../../mock_backend/mock_request_context.dart';
import '../router/app_routes.dart';

/// The service locator. Only the app layer (this folder and the router)
/// reads from it; features receive what they need through constructors.
final GetIt sl = GetIt.instance;

/// Registers every dependency. Call once before `runApp`.
void configureDependencies({AppConfig config = AppConfig.fromEnvironment}) {
  _registerCore(config);
  _registerMockBackend();
  _registerAuth();
  _registerBusiness();
}

/// Arguments for [DoorSaleBloc]: the event and how many tickets are left.
typedef DoorSaleArgs = ({Event event, int ticketsLeft});

void _registerCore(AppConfig config) {
  sl
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton<KeyValueStore>(
      () => const SecureKeyValueStore(FlutterSecureStorage()),
    )
    ..registerLazySingleton<Ticker>(() => const Ticker())
    ..registerLazySingleton<FileSharer>(() => const SharePlusFileSharer())
    ..registerLazySingleton<PhotoPicker>(DevicePhotoPicker.new)
    ..registerLazySingleton<Dio>(
      () => createApiClient(
        config: sl(),
        readToken: () async => (await sl<AuthLocalDataSource>().readSession())?.accessToken,
        // A token the server refuses (expired, or this scanner was removed) signs the app out.
        onSessionRejected: () => sl<SignOut>()(const NoParams()),
      ),
    );
}

/// The in-memory server used when `USE_MOCK_API` is true (the default).
void _registerMockBackend() {
  sl
    ..registerLazySingleton(MockMerchantBackend.new)
    ..registerLazySingleton(
      () => MockRequestContext(
        () async => (await sl<AuthLocalDataSource>().readSession())?.toEntity().user,
      ),
    );
}

void _registerAuth() {
  sl
    // Data
    ..registerLazySingleton<AuthLocalDataSource>(() => AuthLocalDataSource(sl()))
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => sl<AppConfig>().useMockApi
          ? AuthMockDataSource(backend: sl())
          : AuthApiDataSource(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remote: sl(), local: sl()),
    )
    // Use cases
    ..registerLazySingleton(() => RequestOtp(sl()))
    ..registerLazySingleton(() => VerifyOtp(sl()))
    ..registerLazySingleton(() => RegisterBusiness(sl()))
    ..registerLazySingleton(() => JoinTeam(sl()))
    ..registerLazySingleton(() => RestoreSession(sl()))
    ..registerLazySingleton(() => WatchSession(sl()))
    ..registerLazySingleton(() => SignOut(sl()))
    ..registerLazySingleton(() => RefreshSession(sl()))
    // Blocs: one AuthBloc for the whole app, a new bloc per screen otherwise.
    ..registerLazySingleton(
      () => AuthBloc(
        restoreSession: sl(),
        watchSession: sl(),
        signOut: sl(),
        refreshSession: sl(),
      ),
    )
    ..registerFactory(() => LoginBloc(requestOtp: sl()))
    ..registerFactoryParam<OtpBloc, OtpRouteArgs, void>(
      (args, _) => OtpBloc(
        verifyOtp: sl(),
        requestOtp: sl(),
        ticker: sl(),
        phone: args.phone,
        purpose: args.purpose,
      ),
    )
    ..registerFactoryParam<RegisterBusinessBloc, RegisterBusinessRouteArgs, void>(
      (args, _) => RegisterBusinessBloc(
        registerBusiness: sl(),
        registrationToken: args.registrationToken,
      ),
    )
    ..registerFactoryParam<JoinTeamBloc, RegisterBusinessRouteArgs, void>(
      (args, _) => JoinTeamBloc(joinTeam: sl(), registrationToken: args.registrationToken),
    );
}

/// Events, bookings, staff and the screens built on them, answered by the Pin
/// API or by the mock backend.
void _registerBusiness() {
  final useMock = sl<AppConfig>().useMockApi;
  sl
    // Data
    ..registerLazySingleton(() => EventsApiDataSource(sl()))
    ..registerLazySingleton(() => BookingsApiDataSource(sl()))
    ..registerLazySingleton(() => StaffApiDataSource(sl()))
    ..registerLazySingleton<EventsRepository>(
      () => useMock ? MockEventsRepository(backend: sl(), context: sl()) : ApiEventsRepository(sl()),
    )
    ..registerLazySingleton<BookingsRepository>(
      () => useMock
          ? MockBookingsRepository(backend: sl(), context: sl())
          : ApiBookingsRepository(sl()),
    )
    ..registerLazySingleton<StaffRepository>(
      () => useMock ? MockStaffRepository(backend: sl(), context: sl()) : ApiStaffRepository(sl()),
    )
    ..registerLazySingleton(() => PayoutsApiDataSource(sl()))
    ..registerLazySingleton<PayoutsRepository>(
      () => useMock ? MockPayoutsRepository(backend: sl(), context: sl()) : ApiPayoutsRepository(sl()),
    )
    // Use cases
    ..registerLazySingleton(() => WatchBusinessSnapshot(events: sl(), bookings: sl()))
    ..registerLazySingleton(() => CheckInBooking(sl()))
    ..registerLazySingleton(() => SellAtDoor(sl()))
    ..registerLazySingleton(() => CancelBooking(sl()))
    ..registerLazySingleton(() => PublishEvent(sl()))
    ..registerLazySingleton(() => PublishBusTrip(sl()))
    ..registerLazySingleton(() => PublishScreening(sl()))
    ..registerLazySingleton(() => PublishPlace(sl()))
    ..registerLazySingleton(() => SetEventImage(sl()))
    ..registerLazySingleton(() => RemoveEventImage(sl()))
    ..registerLazySingleton(() => WatchTeam(sl()))
    ..registerLazySingleton(() => RemoveStaffMember(sl()))
    ..registerLazySingleton(() => RegenerateJoinCode(sl()))
    ..registerLazySingleton(() => GetPayouts(sl()))
    // Blocs
    ..registerFactory(() => BusinessBloc(watchSnapshot: sl()))
    ..registerFactory(BookingsFilterBloc.new)
    ..registerFactory(() => CheckInBloc(checkIn: sl()))
    ..registerFactoryParam<CancelBookingBloc, String, void>(
      (bookingId, _) => CancelBookingBloc(cancelBooking: sl(), bookingId: bookingId),
    )
    ..registerLazySingleton(() => CoverPhotos(picker: sl(), setImage: sl()))
    ..registerFactory(() => CreateEventBloc(publishEvent: sl(), coverPhotos: sl()))
    ..registerFactory(() => CreateTripBloc(publishBusTrip: sl(), coverPhotos: sl()))
    ..registerFactory(() => CreateScreeningBloc(publishScreening: sl(), coverPhotos: sl()))
    ..registerFactory(() => CreatePlaceBloc(publishPlace: sl(), coverPhotos: sl()))
    ..registerFactoryParam<EventPictureCubit, Event, void>(
      (event, _) => EventPictureCubit(
        eventId: event.id,
        imageUrl: event.imageUrl,
        picker: sl(),
        setImage: sl(),
        removeImage: sl(),
      ),
    )
    ..registerFactoryParam<DoorSaleBloc, DoorSaleArgs, void>(
      (args, _) => DoorSaleBloc(
        sellAtDoor: sl(),
        event: args.event,
        ticketsLeft: args.ticketsLeft,
      ),
    )
    ..registerFactory(
      () => StaffBloc(watchTeam: sl(), removeMember: sl(), regenerateJoinCode: sl()),
    )
    ..registerFactory(() => PayoutsBloc(getPayouts: sl()));
}
