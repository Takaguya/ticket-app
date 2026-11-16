import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../../../mock_backend/mock_bookings.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../auth/domain/entities/pin_user.dart';
import '../../../catalog/domain/entities/bus_departure.dart';
import '../../../catalog/domain/entities/showtime.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/runner_details.dart';
import '../../domain/entities/seat_map.dart';
import '../../domain/entities/snack.dart';
import '../../domain/repositories/booking_repository.dart';

/// Answers from the in-memory [MockBookings] as the person signed in on this
/// device, whom the real server will know from the session token. Waits a
/// little first, so loading states show as they will with the server.
class MockBookingRepository implements BookingRepository {
  MockBookingRepository({
    required this._bookings,
    required this._session,
    this.latency = const Duration(milliseconds: 400),
    this.paymentLatency = const Duration(milliseconds: 1500),
  });

  final MockBookings _bookings;
  final AuthLocalDataSource _session;

  /// Simulated network delay.
  final Duration latency;

  /// How long paying and issuing the tickets takes.
  final Duration paymentLatency;

  @override
  Future<Result<SeatMap>> busSeats(BusDeparture departure) {
    return _answer(() => _bookings.busSeats(departure));
  }

  @override
  Future<Result<SeatMap>> cinemaSeats(Showtime showtime) {
    return _answer(() => _bookings.cinemaSeats(showtime));
  }

  @override
  Future<Result<List<Snack>>> snacks({required String theatreId}) {
    return _answer(() => MockBookings.snacks);
  }

  @override
  Future<Result<List<Promotion>>> promotions() => _answer(() => MockBookings.promotions);

  @override
  Future<Result<RunnerDetails?>> savedRunner() => _asUser(_bookings.savedRunner);

  @override
  Future<Result<Booking>> placeOrder(Order order) {
    return _asUser((user) => _bookings.place(user, order), delay: paymentLatency);
  }

  @override
  Stream<Result<List<Booking>>> watchBookings() async* {
    yield await _asUser(_bookings.bookingsOf);
    yield* _bookings.changes.asyncMap(
      (_) => _asUser(_bookings.bookingsOf, delay: Duration.zero),
    );
  }

  @override
  Future<Result<Booking>> booking(String id) {
    return _asUser((user) {
      final booking = _bookings.booking(user, id);
      if (booking == null) {
        throw const ApiException(
          code: ApiErrorCodes.notFound,
          message: "This booking can't be found.",
          statusCode: 404,
        );
      }
      return booking;
    });
  }

  Future<Result<T>> _answer<T>(T Function() read) {
    return guard(() async {
      await Future<void>.delayed(latency);
      return read();
    });
  }

  Future<Result<T>> _asUser<T>(T Function(PinUser user) read, {Duration? delay}) {
    return guard(() async {
      await Future<void>.delayed(delay ?? latency);
      final session = await _session.readSession();
      if (session == null) {
        throw const ApiException(
          code: ApiErrorCodes.unauthorized,
          message: 'Please log in again.',
          statusCode: 401,
        );
      }
      return read(session.user.toEntity());
    });
  }
}
