import 'dart:async';

import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/gender.dart';
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
  Future<Result<AuthSession>> register({
    required String registrationToken,
    required String name,
    required Gender gender,
    required DateTime dateOfBirth,
    String? email,
  }) {
    return guard(() async {
      final session = await _remote.register(
        registrationToken: registrationToken,
        name: name,
        gender: gender,
        dateOfBirth: dateOfBirth,
        email: email,
      );
      return _signIn(session);
    });
  }

  /// Ends the session on the server when it can be reached, and on this device
  /// always: signing out must work offline.
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

  Future<void> dispose() => _sessions.close();

  /// Saves the session, then tells listeners the person is signed in.
  Future<AuthSession> _signIn(AuthSessionModel model) async {
    await _local.saveSession(model);
    final session = model.toEntity();
    _sessions.add(session);
    return session;
  }
}
