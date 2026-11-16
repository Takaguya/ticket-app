part of 'login_bloc.dart';

enum LoginStatus {
  idle,
  submitting,

  /// The SMS was sent: move on to the code screen.
  codeSent,

  /// Show [LoginState.errorMessage].
  failure,
}

final class LoginState extends Equatable {
  const LoginState({
    this.mode = OtpPurpose.login,
    this.phone = '',
    this.status = LoginStatus.idle,
    this.errorMessage,
  });

  final OtpPurpose mode;

  /// The text as typed.
  final String phone;
  final LoginStatus status;
  final String? errorMessage;

  bool get isPhoneValid => PhoneNumber.isValid(phone);
  bool get isSubmitting => status == LoginStatus.submitting;

  /// The number in the form the API expects.
  String get e164Phone => PhoneNumber.toE164(phone);

  LoginState copyWith({
    OtpPurpose? mode,
    String? phone,
    LoginStatus? status,
    String? errorMessage,
  }) {
    return LoginState(
      mode: mode ?? this.mode,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [mode, phone, status, errorMessage];
}
