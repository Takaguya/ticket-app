import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/services/file_sharer.dart';
import '../../design_system/molecules/message_view.dart';
import '../../features/auth/data/datasources/auth_mock_data_source.dart';
import '../../features/auth/domain/entities/merchant_user.dart';
import '../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../features/auth/presentation/bloc/join_team/join_team_bloc.dart';
import '../../features/auth/presentation/bloc/login/login_bloc.dart';
import '../../features/auth/presentation/bloc/otp/otp_bloc.dart';
import '../../features/auth/presentation/bloc/register_business/register_business_bloc.dart';
import '../../features/auth/presentation/pages/join_team_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/new_account_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/register_business_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/bookings/domain/entities/bookings_csv.dart';
import '../../features/bookings/domain/entities/check_in_result.dart';
import '../../features/bookings/presentation/bloc/bookings_filter/bookings_filter_bloc.dart';
import '../../features/bookings/presentation/bloc/cancel_booking/cancel_booking_bloc.dart';
import '../../features/bookings/presentation/bloc/check_in/check_in_bloc.dart';
import '../../features/bookings/presentation/pages/booking_detail_page.dart';
import '../../features/bookings/presentation/pages/bookings_page.dart';
import '../../features/dashboard/presentation/bloc/business/business_bloc.dart';
import '../../features/dashboard/presentation/pages/today_page.dart';
import '../../features/door_sale/presentation/bloc/door_sale_bloc.dart';
import '../../features/door_sale/presentation/pages/door_sale_page.dart';
import '../../features/events/presentation/bloc/create_event_bloc.dart';
import '../../features/events/presentation/bloc/create_place_bloc.dart';
import '../../features/events/presentation/bloc/create_screening_bloc.dart';
import '../../features/events/presentation/bloc/create_trip_bloc.dart';
import '../../features/events/presentation/bloc/event_picture_cubit.dart';
import '../../features/events/presentation/pages/create_event_page.dart';
import '../../features/events/presentation/pages/create_place_page.dart';
import '../../features/events/presentation/pages/create_screening_page.dart';
import '../../features/events/presentation/pages/create_trip_page.dart';
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/home/presentation/home_tab.dart';
import '../../features/home/presentation/pages/home_shell_page.dart';
import '../../features/payouts/presentation/bloc/payouts_bloc.dart';
import '../../features/scan/presentation/organisms/qr_camera_view.dart';
import '../../features/scan/presentation/pages/scan_page.dart';
import '../../features/scan/presentation/pages/scan_result_page.dart';
import '../../features/staff/presentation/bloc/staff_bloc.dart';
import '../../features/staff/presentation/pages/staff_page.dart';
import '../di/injector.dart';
import 'app_routes.dart';

/// Builds the router.
///
/// * Signed-out screens live under `/login`.
/// * Each tab is a branch of a [StatefulShellRoute], with its own URL and
///   back stack: `/today`, `/scan`, `/bookings`, `/finance`, `/staff`.
/// * Full-screen pages (`/booking/:bookingId`, `/scan-result`,
///   `/create-event`, `/door-sale`) are top-level routes, so they cover the
///   tab bar and "back" returns to whichever tab opened them.
///
/// [_redirect] runs again whenever [authBloc] changes, so signing in or out
/// moves the person to the right place by itself. [cameraBuilder] is
/// replaced in tests, which have no camera.
GoRouter createAppRouter(AuthBloc authBloc, {QrCameraBuilder? cameraBuilder}) {
  final routes = _Routes(authBloc, cameraBuilder ?? _realCamera);
  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: AppPaths.splash,
    refreshListenable: _StreamListenable(authBloc.stream),
    redirect: (context, state) => _redirect(authBloc.state, state.matchedLocation),
    routes: [
      GoRoute(
        name: AppRoutes.splash,
        path: AppPaths.splash,
        builder: (_, _) => const SplashPage(),
      ),
      routes.signIn(),
      routes.tabs(),
      ...routes.fullScreen(),
    ],
  );
}

Widget _realCamera(BuildContext context, ValueChanged<String> onCode) {
  return QrCameraView(onCode: onCode);
}

/// Where to send the person instead of [location], or null to stay.
String? _redirect(AuthState auth, String location) {
  final inSignIn = location.startsWith(AppPaths.login);
  final user = auth.user;
  return switch (auth.status) {
    AuthStatus.unknown => location == AppPaths.splash ? null : AppPaths.splash,
    AuthStatus.unauthenticated => inSignIn ? null : AppPaths.login,
    AuthStatus.authenticated when user != null =>
      inSignIn || location == AppPaths.splash ? _startPath(user) : null,
    AuthStatus.authenticated => null,
  };
}

/// Owners start on Today, scanners on Scan.
String _startPath(MerchantUser user) {
  return HomeTab.startFor(user.role) == HomeTab.today ? AppPaths.today : AppPaths.scan;
}

class _Routes {
  _Routes(this._authBloc, this._cameraBuilder);

  final AuthBloc _authBloc;
  final QrCameraBuilder _cameraBuilder;

  /// Keeps scanners out of owner-only pages, even when opened by URL.
  String? _ownerOnly(BuildContext context, GoRouterState state) {
    final user = _authBloc.state.user;
    if (user == null || user.isOwner) return null;
    return _startPath(user);
  }

  // ---------------------------------------------------------------- sign-in

  GoRoute signIn() {
    return GoRoute(
      name: AppRoutes.login,
      path: AppPaths.login,
      builder: (_, _) => BlocProvider(
        create: (_) => sl<LoginBloc>(),
        child: const LoginPage(),
      ),
      routes: [
        GoRoute(
          name: AppRoutes.otp,
          path: AppPaths.otp,
          // The arguments are lost if the app is restored from the background.
          redirect: (_, state) => state.extra is OtpRouteArgs ? null : AppPaths.login,
          builder: (_, state) {
            final args = state.extra! as OtpRouteArgs;
            return BlocProvider(
              create: (_) => sl<OtpBloc>(param1: args)..add(const OtpStarted()),
              child: OtpPage(hint: _demoCodeHint()),
            );
          },
        ),
        GoRoute(
          name: AppRoutes.newAccount,
          path: AppPaths.newAccount,
          redirect: _requireRegistrationArgs,
          builder: (_, state) =>
              NewAccountPage(args: state.extra! as RegisterBusinessRouteArgs),
          routes: [
            GoRoute(
              name: AppRoutes.registerBusiness,
              path: AppPaths.registerBusiness,
              redirect: _requireRegistrationArgs,
              builder: (_, state) {
                final args = state.extra! as RegisterBusinessRouteArgs;
                return BlocProvider(
                  create: (_) => sl<RegisterBusinessBloc>(param1: args),
                  child: RegisterBusinessPage(phone: args.phone),
                );
              },
            ),
            GoRoute(
              name: AppRoutes.joinTeam,
              path: AppPaths.joinTeam,
              redirect: _requireRegistrationArgs,
              builder: (_, state) {
                final args = state.extra! as RegisterBusinessRouteArgs;
                return BlocProvider(
                  create: (_) => sl<JoinTeamBloc>(param1: args),
                  child: JoinTeamPage(phone: args.phone),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  static String? _requireRegistrationArgs(BuildContext context, GoRouterState state) {
    return state.extra is RegisterBusinessRouteArgs ? null : AppPaths.login;
  }

  /// With the mock API there is no SMS, so the code screen shows the code.
  static String? _demoCodeHint() {
    return sl<AppConfig>().useMockApi
        ? 'Demo mode: no SMS is sent. Use code ${AuthMockDataSource.demoCode}.'
        : null;
  }

  // ------------------------------------------------------------------- tabs

  /// One branch per [HomeTab], in the same order.
  StatefulShellRoute tabs() {
    return StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) => _SignedInScope(
        child: HomeShellPage(navigationShell: navigationShell),
      ),
      branches: [
        for (final tab in HomeTab.values) StatefulShellBranch(routes: [_tabRoute(tab)]),
      ],
    );
  }

  GoRoute _tabRoute(HomeTab tab) {
    return switch (tab) {
      HomeTab.today => GoRoute(
        name: AppRoutes.today,
        path: AppPaths.today,
        redirect: _ownerOnly,
        builder: (_, _) => RepositoryProvider<EventPictureCubitFactory>(
          // The owner can put a picture on an event from this screen.
          create: (_) => (event) => sl<EventPictureCubit>(param1: event),
          child: _CurrentUser(builder: (user) => TodayPage(user: user)),
        ),
      ),
      HomeTab.scan => GoRoute(
        name: AppRoutes.scan,
        path: AppPaths.scan,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<CheckInBloc>(),
          child: ScanPage(cameraBuilder: _cameraBuilder, demoMode: sl<AppConfig>().useMockApi),
        ),
      ),
      HomeTab.bookings => GoRoute(
        name: AppRoutes.bookings,
        path: AppPaths.bookings,
        builder: (_, _) => _CurrentUser(
          // Only owners can download the list.
          builder: (user) => BookingsPage(onDownload: user.isOwner ? _shareCsv : null),
        ),
      ),
      HomeTab.finance => GoRoute(
        name: AppRoutes.finance,
        path: AppPaths.finance,
        redirect: _ownerOnly,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<PayoutsBloc>()..add(const PayoutsRequested()),
          child: const FinancePage(),
        ),
      ),
      HomeTab.staff => GoRoute(
        name: AppRoutes.staff,
        path: AppPaths.staff,
        redirect: _ownerOnly,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<StaffBloc>()..add(const StaffStarted()),
          child: _CurrentUser(builder: (user) => StaffPage(user: user)),
        ),
      ),
    };
  }

  static Future<void> _shareCsv(CsvFile file) {
    return sl<FileSharer>().shareTextFile(
      name: file.name,
      content: file.content,
      mimeType: 'text/csv',
    );
  }

  // ------------------------------------------------------------ full screen

  /// Pages drawn over the tab bar, on the root navigator.
  List<GoRoute> fullScreen() {
    return [
      GoRoute(
        name: AppRoutes.booking,
        path: AppPaths.booking,
        builder: (_, state) {
          final bookingId = state.pathParameters[AppRoutes.bookingIdParam]!;
          return _CurrentUser(
            builder: (user) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => sl<BusinessBloc>()..add(const BusinessStarted())),
                BlocProvider(create: (_) => sl<CheckInBloc>()),
                BlocProvider(create: (_) => sl<CancelBookingBloc>(param1: bookingId)),
              ],
              child: BookingDetailPage(
                bookingId: bookingId,
                currentUserName: user.name,
                showMoney: user.isOwner,
                canCancel: user.isOwner,
              ),
            ),
          );
        },
      ),
      GoRoute(
        name: AppRoutes.scanResult,
        path: AppPaths.scanResult,
        redirect: (_, state) => state.extra is CheckInResult ? null : AppPaths.scan,
        builder: (_, state) => _CurrentUser(
          builder: (user) => ScanResultPage(
            result: state.extra! as CheckInResult,
            currentUserName: user.name,
          ),
        ),
      ),
      GoRoute(
        name: AppRoutes.createEvent,
        path: AppPaths.createEvent,
        redirect: _ownerOnly,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<CreateEventBloc>(),
          child: const CreateEventPage(),
        ),
      ),
      GoRoute(
        name: AppRoutes.createTrip,
        path: AppPaths.createTrip,
        redirect: _ownerOnly,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<CreateTripBloc>(),
          child: const CreateTripPage(),
        ),
      ),
      GoRoute(
        name: AppRoutes.createScreening,
        path: AppPaths.createScreening,
        redirect: _ownerOnly,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<CreateScreeningBloc>(),
          child: const CreateScreeningPage(),
        ),
      ),
      GoRoute(
        name: AppRoutes.createPlace,
        path: AppPaths.createPlace,
        redirect: _ownerOnly,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<CreatePlaceBloc>(),
          child: const CreatePlacePage(),
        ),
      ),
      GoRoute(
        name: AppRoutes.doorSale,
        path: AppPaths.doorSale,
        redirect: _ownerOnly,
        builder: (_, _) => BlocProvider(
          create: (_) => sl<BusinessBloc>()..add(const BusinessStarted()),
          child: const _DoorSaleRoute(),
        ),
      ),
    ];
  }
}

/// Blocs shared by the tabs. Created when someone signs in and dropped when
/// they sign out, so nothing carries over between accounts.
class _SignedInScope extends StatelessWidget {
  const _SignedInScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final userId = context.select((AuthBloc bloc) => bloc.state.user?.id);
    if (userId == null) return const SizedBox.shrink();

    return MultiBlocProvider(
      // A different account gets fresh blocs.
      key: ValueKey(userId),
      providers: [
        BlocProvider(create: (_) => sl<BusinessBloc>()..add(const BusinessStarted())),
        BlocProvider(create: (_) => sl<BookingsFilterBloc>()),
      ],
      child: child,
    );
  }
}

/// Builds [builder] with the signed-in user, or nothing while signing out.
class _CurrentUser extends StatelessWidget {
  const _CurrentUser({required this.builder});

  final Widget Function(MerchantUser user) builder;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    return user == null ? const SizedBox.shrink() : builder(user);
  }
}

/// Opens the door sale for today's event with the tickets that are left.
/// Expects a [BusinessBloc] above it.
class _DoorSaleRoute extends StatelessWidget {
  const _DoorSaleRoute();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BusinessBloc, BusinessState>(
      // The sale works from the numbers at the moment it was opened.
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        final snapshot = state.snapshot;
        final live = snapshot?.liveEvent;
        if (state.status == BusinessStatus.loading) {
          return const Scaffold(body: MessageView.loading());
        }
        if (snapshot == null || live == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const MessageView(
              icon: Icons.event_busy_rounded,
              title: 'No event today',
              message: 'Door sales open on the day of the event.',
            ),
          );
        }
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => sl<DoorSaleBloc>(
                param1: (event: live, ticketsLeft: snapshot.summaryOf(live).left),
              ),
            ),
            BlocProvider(create: (_) => sl<CheckInBloc>()),
          ],
          child: const DoorSalePage(),
        );
      },
    );
  }
}

/// Lets the router listen to a bloc's state stream.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
