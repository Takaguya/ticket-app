import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../entities/business_type.dart';
import '../repositories/auth_repository.dart';

/// Registers a new business. The person registering becomes its owner.
class RegisterBusiness implements UseCase<AuthSession, RegisterBusinessParams> {
  const RegisterBusiness(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(RegisterBusinessParams params) {
    return _repository.registerBusiness(
      registrationToken: params.registrationToken,
      businessName: params.businessName.trim(),
      contactName: params.contactName.trim(),
      type: params.type,
    );
  }
}

class RegisterBusinessParams extends Equatable {
  const RegisterBusinessParams({
    required this.registrationToken,
    required this.businessName,
    required this.contactName,
    required this.type,
  });

  final String registrationToken;
  final String businessName;
  final String contactName;
  final BusinessType type;

  @override
  List<Object?> get props => [registrationToken, businessName, contactName, type];
}
