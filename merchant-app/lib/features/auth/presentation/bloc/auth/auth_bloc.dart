import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/merchant_user.dart';
import '../../../domain/usecases/refresh_session.dart';
import '../../../domain/usecases/restore_session.dart';
import '../../../domain/usecases/sign_out.dart';
import '../../../domain/usecases/watch_session.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Knows whether someone is signed in. Lives for the whole app; the router
/// listens to it to choose between the sign-in screens and the main app.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._restoreSession,
    required WatchSession watchSession,
    required this._signOut,
    required this._refreshSession,
  }) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthRefreshRequested>(_onRefreshRequested);
    on<_AuthSessionChanged>(_onSessionChanged);

    _sessionSubscription = watchSession().listen(
      (session) => add(_AuthSessionChanged(session)),
    );
  }

  final RestoreSession _restoreSession;
  final SignOut _signOut;
  final RefreshSession _refreshSession;
  late final StreamSubscription<AuthSession?> _sessionSubscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await _restoreSession(const NoParams());
    emit(
      result.when(
        success: (session) => session == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(session),
        failure: (_) => const AuthState.unauthenticated(),
      ),
    );
  }

  Future<void> _onSignOutRequested(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    final result = await _signOut(const NoParams());
    // On success the repository announces the sign-out and
    // [_onSessionChanged] updates the state. If clearing the device failed,
    // still leave the signed-in area.
    if (result is FailureResult<void>) emit(const AuthState.unauthenticated());
  }

  /// A change is announced by the repository and handled by [_onSessionChanged].
  /// When the server cannot be reached the app carries on as it is.
  Future<void> _onRefreshRequested(AuthRefreshRequested event, Emitter<AuthState> emit) async {
    if (state.status != AuthStatus.authenticated) return;
    await _refreshSession(const NoParams());
  }

  void _onSessionChanged(_AuthSessionChanged event, Emitter<AuthState> emit) {
    final session = event.session;
    emit(
      session == null ? const AuthState.unauthenticated() : AuthState.authenticated(session),
    );
  }

  @override
  Future<void> close() async {
    await _sessionSubscription.cancel();
    return super.close();
  }
}
