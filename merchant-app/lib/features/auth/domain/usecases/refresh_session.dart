import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Picks up changes to the signed-in person made elsewhere, e.g. Pin
/// approving or suspending the business.
class RefreshSession implements UseCase<void, NoParams> {
  const RefreshSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.refreshUser();
}
