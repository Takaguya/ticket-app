import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

/// One of the person's bookings. Takes the booking ID, e.g. `TK48213377`.
class GetBooking implements UseCase<Booking, String> {
  const GetBooking(this._repository);

  final BookingRepository _repository;

  @override
  Future<Result<Booking>> call(String id) => _repository.booking(id);
}
