import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/runner_details.dart';
import '../repositories/booking_repository.dart';

/// The runner details saved to the account at an earlier race, or null.
class GetSavedRunner implements UseCase<RunnerDetails?, NoParams> {
  const GetSavedRunner(this._repository);

  final BookingRepository _repository;

  @override
  Future<Result<RunnerDetails?>> call(NoParams params) => _repository.savedRunner();
}
