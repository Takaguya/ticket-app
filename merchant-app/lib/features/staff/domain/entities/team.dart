import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/staff_role.dart';

/// Someone who works for the business.
class StaffMember extends Equatable {
  const StaffMember({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final StaffRole role;

  /// `VS` for Vannak Sok.
  String get initials {
    return name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .take(2)
        .join();
  }

  @override
  List<Object?> get props => [id, name, role];
}

/// The business's staff and the code new scanners use to join.
class Team extends Equatable {
  const Team({required this.members, required this.joinCode});

  final List<StaffMember> members;

  /// Six digits, shown as `482 913`.
  final String joinCode;

  @override
  List<Object?> get props => [members, joinCode];
}
