import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/core/storage/key_value_store.dart';
import 'package:merchant/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:merchant/features/auth/data/datasources/auth_mock_data_source.dart';
import 'package:merchant/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:merchant/features/auth/domain/entities/auth_session.dart';
import 'package:merchant/features/auth/domain/entities/business_type.dart';
import 'package:merchant/features/auth/domain/entities/otp_verification.dart';
import 'package:merchant/features/auth/domain/entities/staff_role.dart';

/// Unwraps a successful result or fails the test.
T valueOf<T>(Result<T> result) {
  return result.when(
    success: (value) => value,
    failure: (failure) => fail('Expected success but got $failure'),
  );
}

void main() {
  const newPhone = '+85577000111';

  late KeyValueStore store;
  late AuthRepositoryImpl repository;

  /// A second repository over the same storage, as after an app restart.
  AuthRepositoryImpl reopen() {
    return AuthRepositoryImpl(
      remote: AuthMockDataSource(latency: Duration.zero),
      local: AuthLocalDataSource(store),
    );
  }

  setUp(() {
    store = InMemoryKeyValueStore();
    repository = reopen();
  });

  tearDown(() => repository.dispose());

  Future<OtpVerification> verify(String phone, {String code = AuthMockDataSource.demoCode}) async {
    await repository.requestOtp(phone: phone, purpose: OtpPurpose.login);
    return valueOf(
      await repository.verifyOtp(phone: phone, code: code, purpose: OtpPurpose.login),
    );
  }

  test('a known owner number signs in and the session is saved', () async {
    final verification = await verify(AuthMockDataSource.ownerPhone);

    expect(verification, isA<OtpAuthenticated>());
    final session = (verification as OtpAuthenticated).session;
    expect(session.user.role, StaffRole.owner);
    expect(session.user.businessName, 'Khmer Runners Club');

    // Still signed in after a restart.
    expect(valueOf(await reopen().restoreSession()), session);
  });

  test('a known scanner number signs in as a scanner', () async {
    final verification = await verify(AuthMockDataSource.scannerPhone);

    expect((verification as OtpAuthenticated).session.user.role, StaffRole.scanner);
  });

  test('a wrong code is rejected and nobody is signed in', () async {
    await repository.requestOtp(phone: AuthMockDataSource.ownerPhone, purpose: OtpPurpose.login);
    final result = await repository.verifyOtp(
      phone: AuthMockDataSource.ownerPhone,
      code: '000000',
      purpose: OtpPurpose.login,
    );

    expect(result, const Result<OtpVerification>.failure(InvalidCodeFailure()));
    expect(valueOf(await repository.restoreSession()), isNull);
  });

  test('a code cannot be verified before it was requested', () async {
    final result = await repository.verifyOtp(
      phone: AuthMockDataSource.ownerPhone,
      code: AuthMockDataSource.demoCode,
      purpose: OtpPurpose.login,
    );

    expect(result, const Result<OtpVerification>.failure(InvalidCodeFailure()));
  });

  test('a new number registers a business and becomes its owner', () async {
    final verification = await verify(newPhone);
    expect(verification, isA<OtpRegistrationRequired>());
    // Confirming the number alone does not sign anyone in.
    expect(valueOf(await repository.restoreSession()), isNull);

    final session = valueOf(
      await repository.registerBusiness(
        registrationToken: (verification as OtpRegistrationRequired).registrationToken,
        businessName: 'Kampot Night Market',
        contactName: 'Sophea Lim',
        type: BusinessType.admission,
      ),
    );

    expect(session.user.role, StaffRole.owner);
    expect(session.user.phone, newPhone);
    expect(session.user.name, 'Sophea Lim');
    expect(session.user.businessName, 'Kampot Night Market');
    expect(session.user.businessType, BusinessType.admission);
    expect(valueOf(await repository.restoreSession()), session);
  });

  test('a registration token works only once', () async {
    final verification = await verify(newPhone) as OtpRegistrationRequired;
    Future<Result<AuthSession>> register() {
      return repository.registerBusiness(
        registrationToken: verification.registrationToken,
        businessName: 'Kampot Night Market',
        contactName: 'Sophea Lim',
        type: BusinessType.events,
      );
    }

    expect(await register(), isA<Success<AuthSession>>());
    expect(
      await register(),
      const Result<AuthSession>.failure(
        SessionExpiredFailure('Please confirm your phone number again.'),
      ),
    );
  });

  test('sessionChanges reports the sign-in and then the sign-out', () async {
    final changes = expectLater(
      repository.sessionChanges,
      emitsInOrder([isA<AuthSession>(), isNull]),
    );

    await verify(AuthMockDataSource.ownerPhone);
    await repository.signOut();

    await changes;
    expect(valueOf(await repository.restoreSession()), isNull);
  });
}
