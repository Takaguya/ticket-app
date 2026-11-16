import '../../features/auth/domain/entities/otp_verification.dart';

/// Route names. Navigate with `context.goNamed(AppRoutes.today)` or
/// `context.pushNamed(AppRoutes.booking, pathParameters: {...})` rather than
/// typing paths.
abstract final class AppRoutes {
  static const splash = 'splash';

  // Signed out
  static const login = 'login';
  static const otp = 'otp';
  static const newAccount = 'new-account';
  static const registerBusiness = 'register-business';
  static const joinTeam = 'join-team';

  // Tabs, one branch each
  static const today = 'today';
  static const scan = 'scan';
  static const bookings = 'bookings';
  static const finance = 'finance';
  static const staff = 'staff';

  // Full-screen pages drawn over the tab bar
  static const booking = 'booking';
  static const scanResult = 'scan-result';
  static const createEvent = 'create-event';
  static const createTrip = 'create-trip';
  static const createScreening = 'create-screening';
  static const createPlace = 'create-place';
  static const doorSale = 'door-sale';

  /// Path parameter of [booking].
  static const bookingIdParam = 'bookingId';
}

/// Route paths. Only the router uses these.
abstract final class AppPaths {
  static const splash = '/splash';

  /// Everything under this path is for signed-out people.
  static const login = '/login';
  static const otp = 'otp';
  static const newAccount = 'new';
  static const registerBusiness = 'register';
  static const joinTeam = 'join';

  static const today = '/today';
  static const scan = '/scan';
  static const bookings = '/bookings';
  static const finance = '/finance';
  static const staff = '/staff';

  static const booking = '/booking/:${AppRoutes.bookingIdParam}';
  static const scanResult = '/scan-result';
  static const createEvent = '/create-event';
  static const createTrip = '/create-trip';
  static const createScreening = '/create-screening';
  static const createPlace = '/create-place';
  static const doorSale = '/door-sale';
}

/// Passed to [AppRoutes.otp] as `extra`.
class OtpRouteArgs {
  const OtpRouteArgs({required this.phone, required this.purpose});

  /// E.164 form.
  final String phone;
  final OtpPurpose purpose;
}

/// Passed to [AppRoutes.newAccount], [AppRoutes.registerBusiness] and
/// [AppRoutes.joinTeam] as `extra`.
class RegisterBusinessRouteArgs {
  const RegisterBusinessRouteArgs({required this.registrationToken, required this.phone});

  final String registrationToken;

  /// E.164 form.
  final String phone;
}
