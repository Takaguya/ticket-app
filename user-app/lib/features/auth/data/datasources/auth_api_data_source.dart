import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/otp_verification.dart';
import '../models/auth_session_model.dart';
import '../models/pin_user_model.dart';
import 'auth_remote_data_source.dart';

/// Buyer sign-in on the Pin API: `POST /auth/otp`, `POST /auth/verify` with
/// `app: "user"`, `POST /buyer/register` and `POST /auth/sign-out`.
class AuthApiDataSource implements AuthRemoteDataSource {
  const AuthApiDataSource(this._dio);

  final Dio _dio;

  @override
  Future<void> requestOtp({required String phone, required OtpPurpose purpose}) {
    return apiCall(() => _dio.post<void>('/auth/otp', data: {'phone': phone, 'purpose': purpose.name}));
  }

  @override
  Future<VerifyOtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  }) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/verify',
        data: {'phone': phone, 'code': code, 'purpose': purpose.name, 'app': 'user'},
      );
      return VerifyOtpResponseModel.fromJson(response.data!);
    });
  }

  @override
  Future<AuthSessionModel> register({
    required String registrationToken,
    required String name,
    required Gender gender,
    required DateTime dateOfBirth,
    String? email,
  }) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/buyer/register',
        data: {
          'registrationToken': registrationToken,
          'name': name,
          'gender': gender.name,
          'dateOfBirth': PinUserModel.isoDate(dateOfBirth),
          'email': ?email,
        },
      );
      return AuthSessionModel.fromJson(response.data!);
    });
  }

  /// `POST /auth/sign-out` with the stored token.
  @override
  Future<void> signOut() => apiCall(() => _dio.post<void>(signOutPath));
}
