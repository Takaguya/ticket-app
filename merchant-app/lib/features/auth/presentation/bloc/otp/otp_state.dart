part of 'otp_bloc.dart';

enum OtpStatus {
  editing,
  verifying,
  resending,

  /// The code was right: see [OtpState.verification] for what happens next.
  verified,
}

final class OtpState extends Equatable {
  const OtpState({
    required this.phone,
    required this.purpose,
    this.code = '',
    this.status = OtpStatus.editing,
    this.secondsLeft = 0,
    this.errorMessage,
    this.notice,
    this.verification,
  });

  static const codeLength = 6;

  /// E.164 form.
  final String phone;
  final OtpPurpose purpose;
  final String code;
  final OtpStatus status;

  /// Seconds until a new code can be requested.
  final int secondsLeft;

  /// Shown under the code boxes until the person types again.
  final String? errorMessage;

  /// One-off message for a toast.
  final String? notice;

  /// Set when [status] is [OtpStatus.verified].
  final OtpVerification? verification;

  bool get isCodeComplete => code.length == codeLength;
  bool get isBusy => status != OtpStatus.editing;
  bool get canResend => status == OtpStatus.editing && secondsLeft == 0;

  /// Nullable fields take a function so they can be set back to null.
  OtpState copyWith({
    String? code,
    OtpStatus? status,
    int? secondsLeft,
    String? Function()? errorMessage,
    String? Function()? notice,
    OtpVerification? verification,
  }) {
    return OtpState(
      phone: phone,
      purpose: purpose,
      code: code ?? this.code,
      status: status ?? this.status,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
      notice: notice == null ? this.notice : notice(),
      verification: verification ?? this.verification,
    );
  }

  @override
  List<Object?> get props => [
    phone,
    purpose,
    code,
    status,
    secondsLeft,
    errorMessage,
    notice,
    verification,
  ];
}
