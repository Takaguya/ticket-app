import '../../../../core/error/exceptions.dart';
import '../../../../mock_backend/mock_merchant_backend.dart';
import '../../domain/entities/business_type.dart';
import '../../domain/entities/otp_verification.dart';
import '../../domain/entities/staff_role.dart';
import '../models/auth_session_model.dart';
import '../models/merchant_user_model.dart';
import 'auth_remote_data_source.dart';

/// Stand-in for the server until the backend exists. Accounts live in memory
/// and are lost when the app restarts.
///
/// Every code is [demoCode]. Two accounts are seeded: [ownerPhone] is an
/// owner and [scannerPhone] is a scanner. Any other number is treated as new:
/// it registers a business or joins one with a join code.
///
/// New businesses and scanners are also recorded in [backend], so they show
/// up on the Staff screen.
class AuthMockDataSource implements AuthRemoteDataSource {
  AuthMockDataSource({this.latency = const Duration(milliseconds: 600), this.backend});

  /// The rest of the mock server, if one is running.
  final MockMerchantBackend? backend;

  static const demoCode = '123456';
  static const ownerPhone = '+85512345678';
  static const scannerPhone = '+85598765432';

  /// Simulated network delay.
  final Duration latency;

  final Map<String, MerchantUserModel> _accounts = {
    ownerPhone: const MerchantUserModel(
      id: 'u_1',
      name: 'Vannak Sok',
      phone: ownerPhone,
      role: StaffRole.owner,
      businessId: 'b_1',
      businessName: 'Khmer Runners Club',
      businessType: BusinessType.events,
    ),
    scannerPhone: const MerchantUserModel(
      id: 'u_2',
      name: 'Dara Keo',
      phone: scannerPhone,
      role: StaffRole.scanner,
      businessId: 'b_1',
      businessName: 'Khmer Runners Club',
      businessType: BusinessType.events,
    ),
  };

  /// Business ID -> name and type.
  final Map<String, (String, BusinessType)> _businessInfo = {
    MockMerchantBackend.demoBusinessId: ('Khmer Runners Club', BusinessType.events),
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
  Future<AuthSessionModel> registerBusiness({
    required String registrationToken,
    required String businessName,
    required String contactName,
    required BusinessType type,
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

    final number = _sequence++;
    final owner = MerchantUserModel(
      id: 'u_$number',
      name: contactName,
      phone: phone,
      role: StaffRole.owner,
      businessId: 'b_$number',
      businessName: businessName,
      businessType: type,
    );
    _accounts[phone] = owner;
    _businessInfo[owner.businessId] = (businessName, type);
    backend?.registerBusiness(
      businessId: owner.businessId,
      ownerId: owner.id,
      ownerName: owner.name,
    );
    return _sessionFor(owner);
  }

  @override
  Future<AuthSessionModel> joinTeam({
    required String registrationToken,
    required String name,
    required String joinCode,
  }) async {
    await Future<void>.delayed(latency);
    final phone = _registrations[registrationToken];
    if (phone == null) {
      throw const ApiException(
        code: ApiErrorCodes.invalidRegistration,
        message: 'The phone number must be verified again',
        statusCode: 400,
      );
    }

    // With a backend, only the business's current code works: an owner who
    // creates a new code switches the old one off, the demo code included.
    final backend = this.backend;
    final businessId = backend != null
        ? backend.businessIdForJoinCode(joinCode)
        : (joinCode.replaceAll(RegExp(r'\D'), '') == MockMerchantBackend.demoJoinCode
              ? MockMerchantBackend.demoBusinessId
              : null);
    final business = businessId == null ? null : _businessInfo[businessId];
    if (businessId == null || business == null) {
      // The token stays valid so the person can correct the code.
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: 'That join code is not right. Ask the owner for the current code.',
        statusCode: 400,
      );
    }
    _registrations.remove(registrationToken);

    final scanner = MerchantUserModel(
      id: 'u_${_sequence++}',
      name: name,
      phone: phone,
      role: StaffRole.scanner,
      businessId: businessId,
      businessName: business.$1,
      businessType: business.$2,
    );
    _accounts[phone] = scanner;
    backend?.addScanner(businessId: businessId, memberId: scanner.id, name: name);
    return _sessionFor(scanner);
  }

  /// Mock sessions live on the device only; there is nothing to end here.
  @override
  Future<void> signOut() async {}

  /// The mock has no Pin admins, so a business never changes status here.
  @override
  Future<MerchantUserModel?> currentUser() async => null;

  AuthSessionModel _sessionFor(MerchantUserModel user) {
    return AuthSessionModel(accessToken: 'mock-token-${user.id}', user: user);
  }
}
