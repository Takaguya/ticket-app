import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Follows sign-ins and sign-outs: a session after each sign-in, null after
/// each sign-out.
class WatchSession {
  const WatchSession(this._repository);

  final AuthRepository _repository;

  Stream<AuthSession?> call() => _repository.sessionChanges;
}
