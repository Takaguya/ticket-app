import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/clock.dart';
import '../../features/activity/presentation/pages/activity_page.dart';
import '../../features/auth/data/datasources/auth_mock_data_source.dart';
import '../../features/auth/domain/entities/pin_user.dart';
import '../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../features/auth/presentation/bloc/login/login_bloc.dart';
import '../../features/auth/presentation/bloc/otp/otp_bloc.dart';
import '../../features/auth/presentation/bloc/register/register_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/booking/domain/entities/booking_request.dart';
import '../../features/booking/presentation/bloc/bookings/bookings_bloc.dart';
import '../../features/booking/presentation/bloc/checkout/checkout_bloc.dart';
import '../../features/booking/presentation/bloc/runner_details/runner_details_bloc.dart';
import '../../features/booking/presentation/bloc/seat_selection/seat_selection_bloc.dart';
import '../../features/booking/presentation/bloc/select_tickets/select_tickets_bloc.dart';
import '../../features/booking/presentation/bloc/snacks/snacks_bloc.dart';
import '../../features/booking/presentation/bloc/ticket/ticket_bloc.dart';
import '../../features/booking/presentation/pages/checkout_page.dart';
import '../../features/booking/presentation/pages/runner_details_page.dart';
import '../../features/booking/presentation/pages/seats_page.dart';
import '../../features/booking/presentation/pages/select_tickets_page.dart';
import '../../features/booking/presentation/pages/snacks_page.dart';
import '../../features/booking/presentation/pages/ticket_page.dart';
import '../../features/catalog/domain/entities/available_categories.dart';
import '../../features/catalog/domain/entities/listing.dart';
import '../../features/catalog/domain/entities/ticket_category.dart';
import '../../features/catalog/presentation/bloc/bus_search/bus_search_bloc.dart';
import '../../features/catalog/presentation/bloc/listing_detail/listing_detail_bloc.dart';
import '../../features/catalog/presentation/bloc/listings/listings_bloc.dart';
import '../../features/catalog/presentation/bloc/search/search_bloc.dart';
import '../../features/catalog/presentation/pages/bus_search_page.dart';
import '../../features/catalog/presentation/pages/category_page.dart';
import '../../features/catalog/presentation/pages/listing_detail_page.dart';
import '../../features/catalog/presentation/pages/search_page.dart';
import '../../features/catalog/presentation/pages/tickets_hub_page.dart';
import '../../features/home/presentation/home_tab.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/home_shell_page.dart';
import '../../features/messages/presentation/pages/messages_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../di/injector.dart';
import 'app_routes.dart';

/// Builds the router.
///
/// * Signed-out screens live under `/login`.
/// * Each tab is a branch of a [StatefulShellRoute], with its own URL and
///   back stack: `/home`, `/activity`, `/messages`, `/profile`.
/// * The catalogue (`/tickets`, `/tickets/search`, `/tickets/bus`,
///   `/tickets/:category`, `/listing/:listingId`) and the booking steps
///   (`/book/...`) are top-level routes, so their pages cover the tab bar
///   and "back" returns to whichever page opened them.
/// * A ticket (`/activity/:bookingId`) also covers the tab bar, with the
///   Activity list under it.
///
/// [_redirect] runs again whenever [authBloc] changes, so signing in or out
/// moves the person to the right place by itself.
GoRouter createAppRouter(AuthBloc authBloc) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.splash,
    refreshListenable: _StreamListenable(authBloc.stream),
    redirect: (context, state) => _redirect(authBloc.state, state.matchedLocation),
    routes: [
      GoRoute(
        name: AppRoutes.splash,
        path: AppPaths.splash,
        builder: (_, _) => const SplashPage(),
      ),
      _signIn(),
      _tabs(rootNavigatorKey),
      ..._catalog(),
      ..._booking(),
    ],
  );
}

/// Where to send the person instead of [location], or null to stay.
String? _redirect(AuthState auth, String location) {
  final inSignIn = location.startsWith(AppPaths.login);
  return switch (auth.status) {
    AuthStatus.unknown => location == AppPaths.splash ? null : AppPaths.splash,
    AuthStatus.unauthenticated => inSignIn ? null : AppPaths.login,
    AuthStatus.authenticated => inSignIn || location == AppPaths.splash ? AppPaths.home : null,
  };
}

// ------------------------------------------------------------------ sign-in

GoRoute _signIn() {
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
            // There is no SMS yet, so the code screen says which code to use.
            child: const OtpPage(
              hint: 'Demo mode: no SMS is sent. Use code ${AuthMockDataSource.demoCode}.',
            ),
          );
        },
      ),
      GoRoute(
        name: AppRoutes.register,
        path: AppPaths.register,
        redirect: (_, state) => state.extra is RegisterRouteArgs ? null : AppPaths.login,
        builder: (_, state) {
          final args = state.extra! as RegisterRouteArgs;
          return BlocProvider(
            create: (_) => sl<RegisterBloc>(param1: args),
            child: RegisterPage(phone: args.phone, clock: sl<Clock>()),
          );
        },
      ),
    ],
  );
}

// --------------------------------------------------------------------- tabs

/// One branch per [HomeTab], in the same order.
StatefulShellRoute _tabs(GlobalKey<NavigatorState> rootNavigatorKey) {
  return StatefulShellRoute.indexedStack(
    builder: (_, _, navigationShell) => HomeShellPage(navigationShell: navigationShell),
    branches: [
      for (final tab in HomeTab.values)
        StatefulShellBranch(routes: [_tabRoute(tab, rootNavigatorKey)]),
    ],
  );
}

GoRoute _tabRoute(HomeTab tab, GlobalKey<NavigatorState> rootNavigatorKey) {
  return switch (tab) {
    HomeTab.home => GoRoute(
      name: AppRoutes.home,
      path: AppPaths.home,
      builder: (_, _) => BlocProvider(
        create: (_) => sl<ListingsBloc>(param1: (category: null))..add(const ListingsRequested()),
        child: _CurrentUser(
          builder: (user) => HomePage(firstName: user.firstName, clock: sl<Clock>()),
        ),
      ),
    ),
    HomeTab.activity => GoRoute(
      name: AppRoutes.activity,
      path: AppPaths.activity,
      builder: (_, _) => BlocProvider(
        create: (_) => sl<BookingsBloc>()..add(const BookingsStarted()),
        child: const ActivityPage(),
      ),
      routes: [
        GoRoute(
          name: AppRoutes.ticket,
          path: AppPaths.ticket,
          // Over the tab bar; "back" shows the Activity list.
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) {
            final args = state.extra is TicketRouteArgs ? state.extra! as TicketRouteArgs : null;
            return BlocProvider(
              create: (_) => sl<TicketBloc>(
                param1: (
                  bookingId: state.pathParameters[AppRoutes.bookingIdParam]!,
                  booking: args?.booking,
                ),
              )..add(const TicketStarted()),
              child: TicketPage(clock: sl<Clock>(), justIssued: args?.justIssued ?? false),
            );
          },
        ),
      ],
    ),
    HomeTab.messages => GoRoute(
      name: AppRoutes.messages,
      path: AppPaths.messages,
      builder: (_, _) => const MessagesPage(),
    ),
    HomeTab.profile => GoRoute(
      name: AppRoutes.profile,
      path: AppPaths.profile,
      builder: (_, _) => _CurrentUser(builder: (user) => ProfilePage(user: user)),
    ),
  };
}

// ------------------------------------------------------------------ catalog

/// Pages drawn over the tab bar, on the root navigator.
List<GoRoute> _catalog() {
  return [
    GoRoute(
      name: AppRoutes.tickets,
      path: AppPaths.tickets,
      builder: (_, _) => BlocProvider(
        create: (_) => sl<ListingsBloc>(param1: (category: null))..add(const ListingsRequested()),
        child: TicketsHubPage(available: sl<AvailableCategories>()),
      ),
    ),
    GoRoute(
      name: AppRoutes.ticketSearch,
      path: AppPaths.ticketSearch,
      builder: (_, _) => BlocProvider(
        create: (_) => sl<SearchBloc>(),
        child: const SearchPage(),
      ),
    ),
    GoRoute(
      name: AppRoutes.busTickets,
      path: AppPaths.busTickets,
      // Not on sale with the Pin API yet, e.g. from an old link.
      redirect: (_, _) => sl<AvailableCategories>().isOnSale(TicketCategory.bus) ? null : AppPaths.tickets,
      builder: (_, state) => BlocProvider(
        create: (_) => sl<BusSearchBloc>(
          param1: (routeId: state.uri.queryParameters[AppRoutes.routeQuery]),
        )..add(const BusSearchStarted()),
        child: const BusSearchPage(),
      ),
    ),
    GoRoute(
      name: AppRoutes.ticketCategory,
      path: AppPaths.ticketCategory,
      // An unknown category, or one not on sale yet, e.g. from an old link,
      // goes to the Tickets page.
      redirect: (_, state) {
        final category = _categoryOf(state);
        return category == null || !sl<AvailableCategories>().isOnSale(category) ? AppPaths.tickets : null;
      },
      builder: (_, state) {
        final category = _categoryOf(state)!;
        return BlocProvider(
          create: (_) => sl<ListingsBloc>(param1: (category: category))..add(const ListingsRequested()),
          child: CategoryPage(category: category),
        );
      },
    ),
    GoRoute(
      name: AppRoutes.listing,
      path: AppPaths.listing,
      builder: (_, state) => BlocProvider(
        create: (_) => sl<ListingDetailBloc>(
          param1: state.pathParameters[AppRoutes.listingIdParam]!,
        )..add(const ListingDetailStarted()),
        child: const ListingDetailPage(),
      ),
    ),
  ];
}

// ------------------------------------------------------------------ booking

/// The booking steps, over the tab bar. Each gets what is being booked as
/// `extra`. That is lost if the app is restored from the background; the
/// step then goes to the Tickets page.
List<GoRoute> _booking() {
  return [
    GoRoute(
      name: AppRoutes.selectTickets,
      path: AppPaths.selectTickets,
      redirect: (_, state) =>
          state.extra is EventListing || state.extra is AdmissionListing ? null : AppPaths.tickets,
      builder: (_, state) => BlocProvider(
        create: (_) =>
            sl<SelectTicketsBloc>(param1: state.extra! as Listing)..add(const SelectTicketsStarted()),
        child: const SelectTicketsPage(),
      ),
    ),
    GoRoute(
      name: AppRoutes.runnerDetails,
      path: AppPaths.runnerDetails,
      redirect: (_, state) => state.extra is EventRequest ? null : AppPaths.tickets,
      builder: (_, state) {
        final request = state.extra! as EventRequest;
        return _CurrentUser(
          builder: (user) => BlocProvider(
            create: (_) => sl<RunnerDetailsBloc>(param1: user)..add(const RunnerDetailsStarted()),
            child: RunnerDetailsPage(request: request),
          ),
        );
      },
    ),
    GoRoute(
      name: AppRoutes.seats,
      path: AppPaths.seats,
      redirect: (_, state) =>
          state.extra is BusRequest || state.extra is CinemaRequest ? null : AppPaths.tickets,
      builder: (_, state) => BlocProvider(
        create: (_) =>
            sl<SeatSelectionBloc>(param1: state.extra! as BookingRequest)
              ..add(const SeatSelectionStarted()),
        child: SeatsPage(sellsSnacks: sl<AvailableCategories>().sellsSnacks),
      ),
    ),
    GoRoute(
      name: AppRoutes.snacks,
      path: AppPaths.snacks,
      redirect: (_, state) => state.extra is CinemaRequest ? null : AppPaths.tickets,
      builder: (_, state) => BlocProvider(
        create: (_) =>
            sl<SnacksBloc>(param1: state.extra! as CinemaRequest)..add(const SnacksStarted()),
        child: const SnacksPage(),
      ),
    ),
    GoRoute(
      name: AppRoutes.checkout,
      path: AppPaths.checkout,
      redirect: (_, state) => state.extra is CheckoutRouteArgs ? null : AppPaths.tickets,
      builder: (_, state) {
        final args = state.extra! as CheckoutRouteArgs;
        return BlocProvider(
          create: (_) => sl<CheckoutBloc>(
            param1: (request: args.request, saveRunner: args.saveRunner),
          )..add(const CheckoutStarted()),
          child: const CheckoutPage(),
        );
      },
    ),
  ];
}

TicketCategory? _categoryOf(GoRouterState state) {
  final path = state.pathParameters[AppRoutes.categoryParam] ?? '';
  return TicketCategory.fromPath(path);
}

/// Builds [builder] with the signed-in user, or nothing while signing out.
class _CurrentUser extends StatelessWidget {
  const _CurrentUser({required this.builder});

  final Widget Function(PinUser user) builder;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    return user == null ? const SizedBox.shrink() : builder(user);
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
