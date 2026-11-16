import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../../../mock_backend/mock_merchant_backend.dart';
import '../../../../mock_backend/mock_request_context.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/repositories/bookings_repository.dart';

/// [BookingsRepository] answered by the in-memory mock backend. Replaced by
/// an API-backed implementation once the server exists.
class MockBookingsRepository implements BookingsRepository {
  const MockBookingsRepository({required this._backend, required this._context});

  final MockMerchantBackend _backend;
  final MockRequestContext _context;

  @override
  Stream<List<Booking>> watchBookings() async* {
    final user = await _context.user();
    if (user == null) return;
    yield* _backend.watchBookings(user.businessId);
  }

  @override
  Future<Result<CheckInResult>> checkIn({required String eventId, required String code}) {
    return guard(() async {
      final user = await _context.requireUser();
      return _backend.checkIn(
        businessId: user.businessId,
        eventId: eventId,
        code: code,
        staffName: user.name,
      );
    });
  }

  @override
  Future<Result<Booking>> sellAtDoor(DoorSaleRequest request) {
    return guard(() async {
      final owner = await _context.requireOwner();
      return _backend.sellAtDoor(owner.businessId, request);
    });
  }

  @override
  Future<Result<Booking>> cancelBooking({required String bookingId, required CancelReason reason}) {
    return guard(() async {
      final owner = await _context.requireOwner();
      return _backend.cancelBooking(
        businessId: owner.businessId,
        bookingId: bookingId,
        reason: reason,
        staffName: owner.name,
      );
    });
  }
}
