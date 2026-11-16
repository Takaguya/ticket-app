import '../../../../core/result/result.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

/// The person's bookings now, then again after every new one.
class WatchBookings {
  const WatchBookings(this._repository);

  final BookingRepository _repository;

  Stream<Result<List<Booking>>> call() => _repository.watchBookings();
}
