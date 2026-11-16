import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/exceptions.dart';
import 'package:merchant/features/auth/data/datasources/auth_mock_data_source.dart';
import 'package:merchant/features/auth/domain/entities/otp_verification.dart';
import 'package:merchant/features/auth/domain/entities/staff_role.dart';
import 'package:merchant/mock_backend/mock_merchant_backend.dart';

void main() {
  late MockMerchantBackend backend;
  late AuthMockDataSource auth;

  setUp(() {
    backend = MockMerchantBackend(latency: Duration.zero);
    auth = AuthMockDataSource(latency: Duration.zero, backend: backend);
  });

  /// Confirms [phone] with the demo code and returns its registration token.
  Future<String> registrationTokenFor(String phone) async {
    await auth.requestOtp(phone: phone, purpose: OtpPurpose.register);
    final response = await auth.verifyOtp(
      phone: phone,
      code: AuthMockDataSource.demoCode,
      purpose: OtpPurpose.register,
    );
    return response.registrationToken!;
  }

  test('the demo join code adds a scanner to the demo business', () async {
    final token = await registrationTokenFor('+85577000222');

    final session = await auth.joinTeam(
      registrationToken: token,
      name: 'Rithy Heng',
      joinCode: '482 913',
    );

    expect(session.user.role, StaffRole.scanner);
    expect(session.user.businessId, MockMerchantBackend.demoBusinessId);
  });

  test('after the owner creates a new code, the old demo code no longer works', () async {
    final newCode = await backend.regenerateJoinCode(MockMerchantBackend.demoBusinessId);
    final token = await registrationTokenFor('+85577000333');

    await expectLater(
      auth.joinTeam(
        registrationToken: token,
        name: 'Rithy Heng',
        joinCode: MockMerchantBackend.demoJoinCode,
      ),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCodes.rejected)),
    );

    // The token survives the wrong code, so the person can type the new one.
    final session = await auth.joinTeam(
      registrationToken: token,
      name: 'Rithy Heng',
      joinCode: newCode,
    );
    expect(session.user.businessId, MockMerchantBackend.demoBusinessId);
  });
}
