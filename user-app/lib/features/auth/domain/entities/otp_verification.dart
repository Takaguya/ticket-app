import 'package:equatable/equatable.dart';

import 'auth_session.dart';

/// Why a code was requested. It only changes the wording on screen: the
/// server decides whether the phone number already has an account.
enum OtpPurpose { login, register }

/// What a correct code leads to.
sealed class OtpVerification extends Equatable {
  const OtpVerification();
}

/// The phone number belongs to an account. The person is now signed in.
final class OtpAuthenticated extends OtpVerification {
  const OtpAuthenticated(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

/// The phone number is confirmed but has no account yet. The person's details
/// are still needed; [registrationToken] proves the number was verified when
/// they are submitted.
final class OtpRegistrationRequired extends OtpVerification {
  const OtpRegistrationRequired({required this.registrationToken, required this.phone});

  final String registrationToken;

  /// E.164 form.
  final String phone;

  @override
  List<Object?> get props => [registrationToken, phone];
}
