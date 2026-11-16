import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/booking.dart';
import '../repositories/bookings_repository.dart';

/// Sells tickets at the entrance for cash or KHQR.
class SellAtDoor implements UseCase<Booking, DoorSaleRequest> {
  const SellAtDoor(this._repository);

  final BookingsRepository _repository;

  @override
  Future<Result<Booking>> call(DoorSaleRequest params) => _repository.sellAtDoor(params);
}
