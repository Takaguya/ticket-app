import '../../../../core/result/result.dart';
import '../entities/auth_session.dart';
import '../entities/business_type.dart';
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

  /// Creates the business and its owner, then signs the owner in.
  Future<Result<AuthSession>> registerBusiness({
    required String registrationToken,
    required String businessName,
    required String contactName,
    required BusinessType type,
  });

  /// Joins an existing business as a scanner using the join code the owner
  /// shared, then signs the scanner in.
  Future<Result<AuthSession>> joinTeam({
    required String registrationToken,
    required String name,
    required String joinCode,
  });

  Future<Result<void>> signOut();

  /// Asks the server who is signed in now and saves any change, e.g. Pin
  /// approving or suspending the business. Listeners of [sessionChanges] hear
  /// about a change. Does nothing when signed out.
  Future<Result<void>> refreshUser();
}
