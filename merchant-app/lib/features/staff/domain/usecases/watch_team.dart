import '../entities/team.dart';
import '../repositories/staff_repository.dart';

/// Follows the staff list and join code.
class WatchTeam {
  const WatchTeam(this._repository);

  final StaffRepository _repository;

  Stream<Team> call() => _repository.watchTeam();
}
