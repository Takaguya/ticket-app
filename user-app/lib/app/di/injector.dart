import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/usecase/usecase.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/ticker.dart';
import '../../features/auth/data/datasources/auth_api_data_source.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_mock_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/register_account.dart';
import '../../features/auth/domain/usecases/request_otp.dart';
import '../../features/auth/domain/usecases/restore_session.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/domain/usecases/watch_session.dart';
import '../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../features/auth/presentation/bloc/login/login_bloc.dart';
import '../../features/auth/presentation/bloc/otp/otp_bloc.dart';
import '../../features/auth/presentation/bloc/register/register_bloc.dart';
import '../../features/auth/domain/entities/pin_user.dart';
import '../../features/booking/data/datasources/booking_api_data_source.dart';
import '../../features/booking/data/repositories/api_booking_repository.dart';
import '../../features/booking/data/repositories/mock_booking_repository.dart';
import '../../features/booking/domain/entities/booking.dart';
import '../../features/booking/domain/entities/booking_request.dart';
import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/booking/domain/usecases/get_booking.dart';
import '../../features/booking/domain/usecases/get_promotions.dart';
import '../../features/booking/domain/usecases/get_saved_runner.dart';
import '../../features/booking/domain/usecases/get_seat_map.dart';
import '../../features/booking/domain/usecases/get_snacks.dart';
import '../../features/booking/domain/usecases/place_order.dart';
import '../../features/booking/domain/usecases/watch_bookings.dart';
import '../../features/booking/presentation/bloc/bookings/bookings_bloc.dart';
import '../../features/booking/presentation/bloc/checkout/checkout_bloc.dart';
import '../../features/booking/presentation/bloc/runner_details/runner_details_bloc.dart';
import '../../features/booking/presentation/bloc/seat_selection/seat_selection_bloc.dart';
import '../../features/booking/presentation/bloc/select_tickets/select_tickets_bloc.dart';
import '../../features/booking/presentation/bloc/snacks/snacks_bloc.dart';
import '../../features/booking/presentation/bloc/ticket/ticket_bloc.dart';
import '../../features/catalog/data/datasources/catalog_api_data_source.dart';
import '../../features/catalog/data/repositories/api_catalog_repository.dart';
import '../../features/catalog/data/repositories/mock_catalog_repository.dart';
import '../../features/catalog/domain/entities/available_categories.dart';
import '../../features/catalog/domain/entities/listing.dart';
import '../../features/catalog/domain/entities/ticket_category.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/catalog/domain/usecases/find_bus_departures.dart';
import '../../features/catalog/domain/usecases/get_listing.dart';
import '../../features/catalog/domain/usecases/get_place_availability.dart';
import '../../features/catalog/domain/usecases/get_listings.dart';
import '../../features/catalog/domain/usecases/get_showtimes.dart';
import '../../features/catalog/domain/usecases/search_listings.dart';
import '../../features/catalog/presentation/bloc/bus_search/bus_search_bloc.dart';
import '../../features/catalog/presentation/bloc/listing_detail/listing_detail_bloc.dart';
import '../../features/catalog/presentation/bloc/listings/listings_bloc.dart';
import '../../features/catalog/presentation/bloc/search/search_bloc.dart';
import '../../mock_backend/mock_bookings.dart';
import '../../mock_backend/mock_catalog.dart';
import '../router/app_routes.dart';

/// The service locator. Only the app layer (this folder and the router)
/// reads from it; features receive what they need through constructors.
final GetIt sl = GetIt.instance;

/// Arguments for [ListingsBloc]: the category to load, or null for all.
typedef ListingsArgs = ({TicketCategory? category});

/// Arguments for [BusSearchBloc]: the bus route to start with, if any.
typedef BusSearchArgs = ({String? routeId});

/// Arguments for [CheckoutBloc].
typedef CheckoutArgs = ({BookingRequest request, bool saveRunner});

/// Arguments for [TicketBloc]: the booking's ID, and the booking itself when
/// the page opening the ticket already has it.
typedef TicketArgs = ({String bookingId, Booking? booking});

/// Registers every dependency. Call once before `runApp`.
///
/// With `USE_MOCK_API=false` ([config]) sign-in, events, promo codes, runner
/// details and bookings come from the Pin API; otherwise everything is
/// answered from memory.
///
/// Tests pass an in-memory [store], a fixed [clock] and no [mockLatency].
void configureDependencies({
  AppConfig config = AppConfig.fromEnvironment,
  KeyValueStore? store,
  Clock clock = const Clock(),
  Duration mockLatency = const Duration(milliseconds: 500),
}) {
  _registerCore(config, store, clock);
  _registerAuth(config, mockLatency);
  _registerCatalog(config, mockLatency);
  _registerBooking(config, mockLatency);
}

void _registerCore(AppConfig config, KeyValueStore? store, Clock clock) {
  sl
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton<KeyValueStore>(
      () => store ?? const SecureKeyValueStore(FlutterSecureStorage()),
    )
    ..registerSingleton<Clock>(clock)
    ..registerLazySingleton<Ticker>(() => const Ticker())
    ..registerLazySingleton<Dio>(
      () => createApiClient(
        config: sl(),
        readToken: () async => (await sl<AuthLocalDataSource>().readSession())?.accessToken,
        // A token the server refuses (expired or ended) signs the person out.
        onSessionRejected: () => sl<SignOut>()(const NoParams()),
      ),
    );
}

/// Sign-in: the Pin API, or the mock.
void _registerAuth(AppConfig config, Duration mockLatency) {
  sl
    // Data
    ..registerLazySingleton<AuthLocalDataSource>(() => AuthLocalDataSource(sl()))
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => config.useMockApi ? AuthMockDataSource(latency: mockLatency) : AuthApiDataSource(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remote: sl(), local: sl()),
    )
    // Use cases
    ..registerLazySingleton(() => RequestOtp(sl()))
    ..registerLazySingleton(() => VerifyOtp(sl()))
    ..registerLazySingleton(() => RegisterAccount(sl()))
    ..registerLazySingleton(() => RestoreSession(sl()))
    ..registerLazySingleton(() => WatchSession(sl()))
    ..registerLazySingleton(() => SignOut(sl()))
    // Blocs: one AuthBloc for the whole app, a new bloc per screen otherwise.
    ..registerLazySingleton(
      () => AuthBloc(restoreSession: sl(), watchSession: sl(), signOut: sl()),
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
    ..registerFactoryParam<RegisterBloc, RegisterRouteArgs, void>(
      (args, _) => RegisterBloc(registerAccount: sl(), registrationToken: args.registrationToken),
    );
}

/// Events, buses, films and places from the mock catalogue; with the Pin API,
/// events only, and the other categories are "Coming soon".
void _registerCatalog(AppConfig config, Duration mockLatency) {
  sl
    // Data
    ..registerLazySingleton(() => MockCatalog(clock: sl()))
    ..registerLazySingleton(() => CatalogApiDataSource(sl()))
    ..registerLazySingleton<CatalogRepository>(
      () => config.useMockApi
          ? MockCatalogRepository(catalog: sl(), latency: mockLatency)
          : ApiCatalogRepository(sl()),
    )
    ..registerSingleton<AvailableCategories>(
      config.useMockApi ? AvailableCategories.all : AvailableCategories.pinApi,
    )
    // Use cases
    ..registerLazySingleton(() => GetListings(sl()))
    ..registerLazySingleton(() => GetListing(sl()))
    ..registerLazySingleton(() => SearchListings(sl()))
    ..registerLazySingleton(() => FindBusDepartures(sl()))
    ..registerLazySingleton(() => GetShowtimes(sl()))
    ..registerLazySingleton(() => GetPlaceAvailability(sl()))
    // Blocs
    ..registerFactoryParam<ListingsBloc, ListingsArgs, void>(
      (args, _) => ListingsBloc(getListings: sl(), category: args.category),
    )
    ..registerFactoryParam<ListingDetailBloc, String, void>(
      (listingId, _) => ListingDetailBloc(
        getListing: sl(),
        getShowtimes: sl(),
        clock: sl(),
        listingId: listingId,
      ),
    )
    ..registerFactoryParam<BusSearchBloc, BusSearchArgs, void>(
      (args, _) => BusSearchBloc(
        getListings: sl(),
        findDepartures: sl(),
        clock: sl(),
        initialRouteId: args.routeId,
      ),
    )
    ..registerFactory(() => SearchBloc(searchListings: sl()));
}

/// Seats, snacks, promo codes, paying and bookings from the mock; with the
/// Pin API, event bookings only. The mock's paying takes three times the usual
/// delay, so "Issuing tickets…" can be seen.
void _registerBooking(AppConfig config, Duration mockLatency) {
  sl
    // Data
    ..registerLazySingleton(() => MockBookings(catalog: sl()))
    ..registerLazySingleton(() => BookingApiDataSource(sl()))
    ..registerLazySingleton<BookingRepository>(
      () => config.useMockApi
          ? MockBookingRepository(
              bookings: sl(),
              session: sl(),
              latency: mockLatency,
              paymentLatency: mockLatency * 3,
            )
          : ApiBookingRepository(sl()),
    )
    // Use cases
    ..registerLazySingleton(() => GetSeatMap(sl()))
    ..registerLazySingleton(() => GetSnacks(sl()))
    ..registerLazySingleton(() => GetPromotions(sl()))
    ..registerLazySingleton(() => GetSavedRunner(sl()))
    ..registerLazySingleton(() => PlaceOrder(sl()))
    ..registerLazySingleton(() => WatchBookings(sl()))
    ..registerLazySingleton(() => GetBooking(sl()))
    // Blocs, a new one per page
    ..registerFactoryParam<SelectTicketsBloc, Listing, void>(
      (listing, _) => SelectTicketsBloc(clock: sl(), listing: listing, getPlaceAvailability: sl()),
    )
    ..registerFactoryParam<RunnerDetailsBloc, PinUser, void>(
      (account, _) => RunnerDetailsBloc(getSavedRunner: sl(), clock: sl(), account: account),
    )
    ..registerFactoryParam<SeatSelectionBloc, BookingRequest, void>(
      (request, _) => SeatSelectionBloc(getSeatMap: sl(), request: request),
    )
    ..registerFactoryParam<SnacksBloc, CinemaRequest, void>(
      (request, _) => SnacksBloc(getSnacks: sl(), request: request),
    )
    ..registerFactoryParam<CheckoutBloc, CheckoutArgs, void>(
      (args, _) => CheckoutBloc(
        getPromotions: sl(),
        placeOrder: sl(),
        request: args.request,
        saveRunner: args.saveRunner,
      ),
    )
    ..registerFactory(() => BookingsBloc(watchBookings: sl(), clock: sl()))
    ..registerFactoryParam<TicketBloc, TicketArgs, void>(
      (args, _) => TicketBloc(getBooking: sl(), bookingId: args.bookingId, initial: args.booking),
    );
}
