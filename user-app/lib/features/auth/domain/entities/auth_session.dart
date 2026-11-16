import 'package:equatable/equatable.dart';

import 'pin_user.dart';

/// A signed-in session: who is using the app and the token that proves it.
class AuthSession extends Equatable {
  const AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final PinUser user;

  @override
  List<Object?> get props => [accessToken, user];
}
