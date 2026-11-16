part of 'login_bloc.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// The person switched between "Log in" and "Register".
final class LoginModeChanged extends LoginEvent {
  const LoginModeChanged(this.mode);

  final OtpPurpose mode;

  @override
  List<Object?> get props => [mode];
}

final class LoginPhoneChanged extends LoginEvent {
  const LoginPhoneChanged(this.phone);

  /// The text as typed, e.g. `012 345 678`.
  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// The person tapped "Send code".
final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}
