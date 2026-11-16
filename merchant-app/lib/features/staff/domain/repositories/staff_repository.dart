import '../../../../core/result/result.dart';
import '../entities/team.dart';

/// Staff list and join code. Owner only.
abstract interface class StaffRepository {
  /// The team now, then again after every change.
  Stream<Team> watchTeam();

  /// Removes a scanner. The owner cannot be removed.
  Future<Result<void>> removeMember(String memberId);

  /// Replaces the join code. The old one stops working at once.
  Future<Result<String>> regenerateJoinCode();
}
