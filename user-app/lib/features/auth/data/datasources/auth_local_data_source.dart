import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';
import '../models/auth_session_model.dart';

/// Keeps the session on the device so the person stays signed in.
class AuthLocalDataSource {
  const AuthLocalDataSource(this._store);

  static const _sessionKey = 'auth.session';

  final KeyValueStore _store;

  Future<AuthSessionModel?> readSession() async {
    final raw = await _store.read(_sessionKey);
    if (raw == null) return null;
    try {
      return AuthSessionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // Saved by an older version or damaged: treat the person as signed out.
      await _store.delete(_sessionKey);
      return null;
    }
  }

  Future<void> saveSession(AuthSessionModel session) {
    return _store.write(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() => _store.delete(_sessionKey);
}
