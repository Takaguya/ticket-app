import 'dart:async';

import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/business_type.dart';
import '../../domain/entities/otp_verification.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this._remote, required this._local});

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final StreamController<AuthSession?> _sessions = StreamController.broadcast();

  @override
  Stream<AuthSession?> get sessionChanges => _sessions.stream;

  @override
  Future<Result<AuthSession?>> restoreSession() {
    return guard(() async => (await _local.readSession())?.toEntity());
  }

  @override
  Future<Result<void>> requestOtp({required String phone, required OtpPurpose purpose}) {
    return guard(() => _remote.requestOtp(phone: phone, purpose: purpose));
  }

  @override
  Future<Result<OtpVerification>> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  }) {
    return guard(() async {
      final response = await _remote.verifyOtp(phone: phone, code: code, purpose: purpose);

      final session = response.session;
      if (session != null) return OtpAuthenticated(await _signIn(session));

      final token = response.registrationToken;
      if (token == null) {
        throw const FormatException('Verify answered without a session or a registration token');
      }
      return OtpRegistrationRequired(registrationToken: token, phone: phone);
    });
  }

  @override
  Future<Result<AuthSession>> registerBusiness({
    required String registrationToken,
    required String businessName,
    required String contactName,
    required BusinessType type,
  }) {
    return guard(() async {
      final session = await _remote.registerBusiness(
        registrationToken: registrationToken,
        businessName: businessName,
        contactName: contactName,
        type: type,
      );
      return _signIn(session);
    });
  }

  @override
  Future<Result<AuthSession>> joinTeam({
    required String registrationToken,
    required String name,
    required String joinCode,
  }) {
    return guard(() async {
      final session = await _remote.joinTeam(
        registrationToken: registrationToken,
        name: name,
        joinCode: joinCode,
      );
      return _signIn(session);
    });
  }

  /// Ends the session on the server when it can be reached, and on this device
  /// always: signing out must work offline and with a token the server refused.
  @override
  Future<Result<void>> signOut() {
    return guard(() async {
      try {
        await _remote.signOut();
      } on Object {
        // The device signs out either way.
      }
      await _local.clearSession();
      _sessions.add(null);
    });
  }

  @override
  Future<Result<void>> refreshUser() {
    return guard(() async {
      final saved = await _local.readSession();
      if (saved == null) return;
      final user = await _remote.currentUser();
      if (user == null || user.toEntity() == saved.user.toEntity()) return;
      // Signed out meanwhile (e.g. the server refused the token): keep it that way.
      final current = await _local.readSession();
      if (current?.accessToken != saved.accessToken) return;
      await _signIn(AuthSessionModel(accessToken: saved.accessToken, user: user));
    });
  }

  Future<void> dispose() => _sessions.close();

  /// Saves the session, then tells listeners the person is signed in.
  Future<AuthSession> _signIn(AuthSessionModel model) async {
    await _local.saveSession(model);
    final session = model.toEntity();
    _sessions.add(session);
    return session;
  }

}
