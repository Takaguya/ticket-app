import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/staff_repository.dart';

/// Issues a new join code and returns it. The old code stops working.
class RegenerateJoinCode implements UseCase<String, NoParams> {
  const RegenerateJoinCode(this._repository);

  final StaffRepository _repository;

  @override
  Future<Result<String>> call(NoParams params) => _repository.regenerateJoinCode();
}
