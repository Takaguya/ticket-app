import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Joins a business as a scanner with the owner's join code.
class JoinTeam implements UseCase<AuthSession, JoinTeamParams> {
  const JoinTeam(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(JoinTeamParams params) {
    return _repository.joinTeam(
      registrationToken: params.registrationToken,
      name: params.name.trim(),
      joinCode: params.joinCode.replaceAll(RegExp(r'\D'), ''),
    );
  }
}

class JoinTeamParams extends Equatable {
  const JoinTeamParams({
    required this.registrationToken,
    required this.name,
    required this.joinCode,
  });

  final String registrationToken;
  final String name;

  /// The 6 digits, with or without the space in the middle.
  final String joinCode;

  @override
  List<Object?> get props => [registrationToken, name, joinCode];
}
