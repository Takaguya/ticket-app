import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/promotion.dart';
import '../repositories/booking_repository.dart';

/// The promo codes on offer now.
class GetPromotions implements UseCase<List<Promotion>, NoParams> {
  const GetPromotions(this._repository);

  final BookingRepository _repository;

  @override
  Future<Result<List<Promotion>>> call(NoParams params) => _repository.promotions();
}
