import '../../../auth/domain/entities/staff_role.dart';
import '../../domain/entities/team.dart';

/// The team as `GET /merchant/staff` sends it:
/// `{"joinCode": "482913", "members": [{"id": "...", "name": "Vannak Sok", "role": "owner"}]}`
abstract final class TeamJson {
  static Team team(Map<String, dynamic> json) {
    return Team(
      joinCode: json['joinCode'] as String,
      members: [
        for (final member in json['members'] as List<dynamic>)
          StaffMember(
            id: (member as Map<String, dynamic>)['id'] as String,
            name: member['name'] as String,
            role: StaffRole.values.byName(member['role'] as String),
          ),
      ],
    );
  }
}
