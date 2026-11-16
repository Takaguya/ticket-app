part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// The app started: look for a saved session.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// The person confirmed "Sign out".
final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// The repository reported a sign-in (a session) or a sign-out (null).
final class _AuthSessionChanged extends AuthEvent {
  const _AuthSessionChanged(this.session);

  final AuthSession? session;

  @override
  List<Object?> get props => [session];
}
