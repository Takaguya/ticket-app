import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/payouts.dart';
import '../repositories/payouts_repository.dart';

/// What Pin owes the business now, and its latest payouts. Owners only.
class GetPayouts implements UseCase<PayoutsOverview, NoParams> {
  const GetPayouts(this._repository);

  final PayoutsRepository _repository;

  @override
  Future<Result<PayoutsOverview>> call(NoParams params) => _repository.fetchPayouts();
}
