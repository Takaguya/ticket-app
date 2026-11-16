import '../../../../core/error/exceptions.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/otp_verification.dart';
import '../models/auth_session_model.dart';
import '../models/pin_user_model.dart';
import 'auth_remote_data_source.dart';

/// Stand-in for the server until the Pin API has buyer accounts. Accounts live
/// in memory and are lost when the app restarts.
///
/// Every code is [demoCode]. [demoPhone] (Sokha Chan, from the design) has an
/// account; any other number is new and registers with a few details.
class AuthMockDataSource implements AuthRemoteDataSource {
  AuthMockDataSource({this.latency = const Duration(milliseconds: 600)});

  static const demoCode = '123456';
  static const demoPhone = '+85510222333';

  /// Simulated network delay.
  final Duration latency;

  final Map<String, PinUserModel> _accounts = {
    demoPhone: PinUserModel(
      id: 'u_1',
      name: 'Sokha Chan',
      phone: demoPhone,
      gender: Gender.female,
      dateOfBirth: DateTime(1996, 4, 12),
      email: 'sokha.chan@example.com',
    ),
  };

  /// Phone numbers with a code waiting to be entered.
  final Set<String> _pendingCodes = {};

  /// Registration token -> verified phone number.
  final Map<String, String> _registrations = {};
  int _sequence = 100;

  @override
  Future<void> requestOtp({required String phone, required OtpPurpose purpose}) async {
    await Future<void>.delayed(latency);
    _pendingCodes.add(phone);
  }

  @override
  Future<VerifyOtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  }) async {
    await Future<void>.delayed(latency);
    if (!_pendingCodes.contains(phone) || code != demoCode) {
      throw const ApiException(
        code: ApiErrorCodes.invalidCode,
        message: 'The code is wrong or has expired',
        statusCode: 400,
      );
    }
    _pendingCodes.remove(phone);

    final account = _accounts[phone];
    if (account != null) return VerifyOtpResponseModel(session: _sessionFor(account));

    final token = 'reg_${_sequence++}';
    _registrations[token] = phone;
    return VerifyOtpResponseModel(registrationToken: token);
  }

  @override
  Future<AuthSessionModel> register({
    required String registrationToken,
    required String name,
    required Gender gender,
    required DateTime dateOfBirth,
    String? email,
  }) async {
    await Future<void>.delayed(latency);
    final phone = _registrations.remove(registrationToken);
    if (phone == null) {
      throw const ApiException(
        code: ApiErrorCodes.invalidRegistration,
        message: 'The phone number must be verified again',
        statusCode: 400,
      );
    }

    final user = PinUserModel(
      id: 'u_${_sequence++}',
      name: name,
      phone: phone,
      gender: gender,
      dateOfBirth: dateOfBirth,
      email: email,
    );
    _accounts[phone] = user;
    return _sessionFor(user);
  }

  /// Mock sessions live on the device only; there is nothing to end here.
  @override
  Future<void> signOut() async {}

  AuthSessionModel _sessionFor(PinUserModel user) {
    return AuthSessionModel(accessToken: 'mock-token-${user.id}', user: user);
  }
}
