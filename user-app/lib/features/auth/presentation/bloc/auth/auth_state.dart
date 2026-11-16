part of 'auth_bloc.dart';

enum AuthStatus {
  /// Start-up: the saved session has not been read yet.
  unknown,
  authenticated,
  unauthenticated,
}

final class AuthState extends Equatable {
  const AuthState._({required this.status, this.session});

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(AuthSession session)
    : this._(status: AuthStatus.authenticated, session: session);

  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);

  final AuthStatus status;

  /// Set only when [status] is [AuthStatus.authenticated].
  final AuthSession? session;

  PinUser? get user => session?.user;

  @override
  List<Object?> get props => [status, session];
}
