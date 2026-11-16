import '../../domain/entities/auth_session.dart';
import 'merchant_user_model.dart';

/// [AuthSession] as the API sends it and as it is saved on the device:
/// `{"accessToken": "...", "user": {...}}`
class AuthSessionModel {
  const AuthSessionModel({required this.accessToken, required this.user});

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      accessToken: json['accessToken'] as String,
      user: MerchantUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  factory AuthSessionModel.fromEntity(AuthSession session) {
    return AuthSessionModel(
      accessToken: session.accessToken,
      user: MerchantUserModel.fromEntity(session.user),
    );
  }

  final String accessToken;
  final MerchantUserModel user;

  Map<String, dynamic> toJson() => {'accessToken': accessToken, 'user': user.toJson()};

  AuthSession toEntity() => AuthSession(accessToken: accessToken, user: user.toEntity());
}

/// Answer to `POST /auth/verify`. Exactly one field is set: [session] when
/// the phone number has an account, [registrationToken] when it does not.
class VerifyOtpResponseModel {
  const VerifyOtpResponseModel({this.session, this.registrationToken});

  factory VerifyOtpResponseModel.fromJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>?;
    return VerifyOtpResponseModel(
      session: session == null ? null : AuthSessionModel.fromJson(session),
      registrationToken: json['registrationToken'] as String?,
    );
  }

  final AuthSessionModel? session;
  final String? registrationToken;
}
