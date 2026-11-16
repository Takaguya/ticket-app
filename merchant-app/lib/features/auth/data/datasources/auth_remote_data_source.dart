import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/business_type.dart';
import '../../domain/entities/otp_verification.dart';
import '../models/auth_session_model.dart';
import '../models/merchant_user_model.dart';

/// The auth part of the Pin API. Implementations throw `ApiException` or
/// `NetworkException`.
abstract interface class AuthRemoteDataSource {
  Future<void> requestOtp({required String phone, required OtpPurpose purpose});

  Future<VerifyOtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  });

  Future<AuthSessionModel> registerBusiness({
    required String registrationToken,
    required String businessName,
    required String contactName,
    required BusinessType type,
  });

  Future<AuthSessionModel> joinTeam({
    required String registrationToken,
    required String name,
    required String joinCode,
  });

  /// Ends the session on the server, so its token stops working there too.
  Future<void> signOut();

  /// The signed-in person as the server knows them now, e.g. after Pin
  /// approved or suspended their business. Null when there is nothing newer
  /// to learn.
  Future<MerchantUserModel?> currentUser();
}

/// Talks to the real server.
///
/// `POST /auth/otp` and `POST /auth/verify` come from the developer handoff.
/// `POST /merchant/businesses` is a proposal: the handoff describes business
/// registration but does not name an endpoint for it.
class AuthApiDataSource implements AuthRemoteDataSource {
  const AuthApiDataSource(this._dio);

  final Dio _dio;

  @override
  Future<void> requestOtp({required String phone, required OtpPurpose purpose}) async {
    try {
      await _dio.post<void>('/auth/otp', data: {'phone': phone, 'purpose': purpose.name});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<VerifyOtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/verify',
        data: {'phone': phone, 'code': code, 'purpose': purpose.name, 'app': 'merchant'},
      );
      return VerifyOtpResponseModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<AuthSessionModel> registerBusiness({
    required String registrationToken,
    required String businessName,
    required String contactName,
    required BusinessType type,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/businesses',
        data: {
          'registrationToken': registrationToken,
          'businessName': businessName,
          'contactName': contactName,
          'type': type.name,
        },
      );
      return AuthSessionModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// `POST /merchant/staff/join` from the handoff.
  @override
  Future<AuthSessionModel> joinTeam({
    required String registrationToken,
    required String name,
    required String joinCode,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/staff/join',
        data: {'registrationToken': registrationToken, 'name': name, 'joinCode': joinCode},
      );
      return AuthSessionModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// `POST /auth/sign-out` with the stored token.
  @override
  Future<void> signOut() => apiCall(() => _dio.post<void>(signOutPath));

  /// `GET /me` with the stored token.
  @override
  Future<MerchantUserModel?> currentUser() {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/me');
      return MerchantUserModel.fromJson(response.data!);
    });
  }
}
