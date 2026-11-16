import '../../domain/entities/gender.dart';
import '../../domain/entities/otp_verification.dart';
import '../models/auth_session_model.dart';

/// The sign-in part of the server. Implementations throw `ApiException` or
/// `NetworkException`: [AuthMockDataSource] answers from memory,
/// [AuthApiDataSource] from the Pin API, chosen in the injector.
abstract interface class AuthRemoteDataSource {
  Future<void> requestOtp({required String phone, required OtpPurpose purpose});

  Future<VerifyOtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  });

  Future<AuthSessionModel> register({
    required String registrationToken,
    required String name,
    required Gender gender,
    required DateTime dateOfBirth,
    String? email,
  });

  /// Ends the session on the server, so its token stops working there too.
  Future<void> signOut();
}
