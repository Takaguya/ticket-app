import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../entities/gender.dart';
import '../repositories/auth_repository.dart';

/// Creates the account for a confirmed new phone number and signs the person in.
class RegisterAccount implements UseCase<AuthSession, RegisterAccountParams> {
  const RegisterAccount(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(RegisterAccountParams params) {
    return _repository.register(
      registrationToken: params.registrationToken,
      name: params.name,
      gender: params.gender,
      dateOfBirth: params.dateOfBirth,
      email: params.email,
    );
  }
}

class RegisterAccountParams extends Equatable {
  const RegisterAccountParams({
    required this.registrationToken,
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    this.email,
  });

  final String registrationToken;
  final String name;
  final Gender gender;
  final DateTime dateOfBirth;
  final String? email;

  @override
  List<Object?> get props => [registrationToken, name, gender, dateOfBirth, email];
}
