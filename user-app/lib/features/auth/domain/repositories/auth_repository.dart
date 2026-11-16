import '../../../../core/result/result.dart';
import '../entities/auth_session.dart';
import '../entities/gender.dart';
import '../entities/otp_verification.dart';

/// Sign-in, registration and the stored session.
abstract interface class AuthRepository {
  /// Emits the new session after every sign-in, and null after sign-out.
  Stream<AuthSession?> get sessionChanges;

  /// The session saved on this device, or null when signed out.
  Future<Result<AuthSession?>> restoreSession();

  /// Sends a 6-digit code by SMS to [phone] (E.164).
  Future<Result<void>> requestOtp({required String phone, required OtpPurpose purpose});

  /// Checks the code. Signs the person in when the number has an account.
  Future<Result<OtpVerification>> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  });

  /// Creates the account for a confirmed new number, then signs the person in.
  Future<Result<AuthSession>> register({
    required String registrationToken,
    required String name,
    required Gender gender,
    required DateTime dateOfBirth,
    String? email,
  });

  Future<Result<void>> signOut();
}
