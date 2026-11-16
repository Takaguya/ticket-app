import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Reads the session saved on this device, if any. Run once at start-up.
class RestoreSession implements UseCase<AuthSession?, NoParams> {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession?>> call(NoParams params) => _repository.restoreSession();
}
