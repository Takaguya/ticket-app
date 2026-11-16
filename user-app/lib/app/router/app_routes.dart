import '../../features/auth/domain/entities/otp_verification.dart';
import '../../features/booking/domain/entities/booking.dart';
import '../../features/booking/domain/entities/booking_request.dart';

/// Route names. Navigate with `context.goNamed(AppRoutes.home)` or
/// `context.pushNamed(AppRoutes.listing, pathParameters: {...})` rather than
/// typing paths.
abstract final class AppRoutes {
  static const splash = 'splash';

  // Signed out
  static const login = 'login';
  static const otp = 'otp';
  static const register = 'register';

  // Tabs, one branch each
  static const home = 'home';
  static const activity = 'activity';
  static const messages = 'messages';
  static const profile = 'profile';

  // Full-screen pages drawn over the tab bar
  static const tickets = 'tickets';
  static const ticketSearch = 'ticket-search';
  static const busTickets = 'bus-tickets';
  static const ticketCategory = 'ticket-category';
  static const listing = 'listing';

  // Booking steps, drawn over the tab bar
  static const selectTickets = 'select-tickets';
  static const runnerDetails = 'runner-details';
  static const seats = 'seats';
  static const snacks = 'snacks';
  static const checkout = 'checkout';

  /// A booking's ticket, drawn over the Activity tab.
  static const ticket = 'ticket';

  /// Path parameter of [ticketCategory]: `events`, `cinema` or `admission`.
  static const categoryParam = 'category';

  /// Path parameter of [listing].
  static const listingIdParam = 'listingId';

  /// Path parameter of [ticket], e.g. `TK48213377`.
  static const bookingIdParam = 'bookingId';

  /// Optional query parameter of [busTickets]: the bus route to start with.
  static const routeQuery = 'route';
}

/// Route paths. Only the router uses these.
abstract final class AppPaths {
  static const splash = '/splash';

  /// Everything under this path is for signed-out people.
  static const login = '/login';
  static const otp = 'otp';
  static const register = 'details';

  static const home = '/home';
  static const activity = '/activity';
  static const messages = '/messages';
  static const profile = '/profile';

  static const tickets = '/tickets';
  static const ticketSearch = '/tickets/search';
  static const busTickets = '/tickets/bus';

  /// Matched after [ticketSearch] and [busTickets], so `search` and `bus` never
  /// land here.
  static const ticketCategory = '/tickets/:${AppRoutes.categoryParam}';
  static const listing = '/listing/:${AppRoutes.listingIdParam}';

  /// The booking steps get what is being booked as `extra`.
  static const selectTickets = '/book/tickets';
  static const runnerDetails = '/book/runner';
  static const seats = '/book/seats';
  static const snacks = '/book/snacks';
  static const checkout = '/book/checkout';

  /// Under [activity]: `/activity/TK48213377`.
  static const ticket = ':${AppRoutes.bookingIdParam}';
}

/// Passed to [AppRoutes.otp] as `extra`.
class OtpRouteArgs {
  const OtpRouteArgs({required this.phone, required this.purpose});

  /// E.164 form.
  final String phone;
  final OtpPurpose purpose;
}

/// Passed to [AppRoutes.register] as `extra`.
class RegisterRouteArgs {
  const RegisterRouteArgs({required this.registrationToken, required this.phone});

  final String registrationToken;

  /// E.164 form.
  final String phone;
}

/// Passed to [AppRoutes.checkout] as `extra`.
class CheckoutRouteArgs {
  const CheckoutRouteArgs({required this.request, this.saveRunner = false});

  final BookingRequest request;

  /// Keep the runner's details on the account.
  final bool saveRunner;
}

/// Passed to [AppRoutes.ticket] as `extra` by pages that already have the
/// booking. Without it the ticket page loads the booking by its ID.
class TicketRouteArgs {
  const TicketRouteArgs({required this.booking, this.justIssued = false});

  final Booking booking;

  /// Right after paying: the page says the tickets were issued.
  final bool justIssued;
}
