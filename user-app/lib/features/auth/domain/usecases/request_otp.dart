import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/otp_verification.dart';
import '../repositories/auth_repository.dart';

/// Sends a 6-digit code by SMS.
class RequestOtp implements UseCase<void, RequestOtpParams> {
  const RequestOtp(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(RequestOtpParams params) {
    return _repository.requestOtp(phone: params.phone, purpose: params.purpose);
  }
}

class RequestOtpParams extends Equatable {
  const RequestOtpParams({required this.phone, required this.purpose});

  /// E.164 form.
  final String phone;
  final OtpPurpose purpose;

  @override
  List<Object?> get props => [phone, purpose];
}
