import '../../../../core/error/guard.dart';
import '../../../../core/network/polled_resource.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/team.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/staff_api_data_source.dart';

/// [StaffRepository] answered by the Pin API. The team is polled while the
/// Staff screen is open, so scanners who join show up there.
class ApiStaffRepository implements StaffRepository {
  ApiStaffRepository(this._api, {Duration pollEvery = const Duration(seconds: 15)})
    : _team = PolledResource(fetch: _api.fetchTeam, interval: pollEvery);

  final StaffApiDataSource _api;
  final PolledResource<Team> _team;

  @override
  Stream<Team> watchTeam() => _team.watch();

  @override
  Future<Result<void>> removeMember(String memberId) {
    return guard(() async {
      await _api.removeMember(memberId);
      _team.update(
        (team) => Team(
          members: [for (final member in team.members) if (member.id != memberId) member],
          joinCode: team.joinCode,
        ),
      );
    });
  }

  @override
  Future<Result<String>> regenerateJoinCode() {
    return guard(() async {
      final code = await _api.regenerateJoinCode();
      _team.update((team) => Team(members: team.members, joinCode: code));
      return code;
    });
  }
}
