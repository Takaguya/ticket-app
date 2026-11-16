import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/booking.dart';
import '../entities/order.dart';
import '../repositories/booking_repository.dart';

/// Pays for the order and issues the tickets.
class PlaceOrder implements UseCase<Booking, Order> {
  const PlaceOrder(this._repository);

  final BookingRepository _repository;

  @override
  Future<Result<Booking>> call(Order order) => _repository.placeOrder(order);
}
