import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/otp_verification.dart';
import '../repositories/auth_repository.dart';

/// Checks the code the person typed.
class VerifyOtp implements UseCase<OtpVerification, VerifyOtpParams> {
  const VerifyOtp(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<OtpVerification>> call(VerifyOtpParams params) {
    return _repository.verifyOtp(
      phone: params.phone,
      code: params.code,
      purpose: params.purpose,
    );
  }
}

class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({required this.phone, required this.code, required this.purpose});

  /// E.164 form.
  final String phone;
  final String code;
  final OtpPurpose purpose;

  @override
  List<Object?> get props => [phone, code, purpose];
}
