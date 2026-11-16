import 'package:equatable/equatable.dart';

/// What went wrong, in terms the domain and presentation layers can act on.
/// [message] is written for the person using the app.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// No answer from the server: no connection, or the server is down.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = "Can't reach Pin right now. Check your connection and try again.",
  ]);
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong. Please try again.']);
}

final class InvalidCodeFailure extends Failure {
  const InvalidCodeFailure([
    super.message = 'That code is not right. Check the SMS and try again.',
  ]);
}

/// The server understood the request and said no, e.g. "Only 2 tickets
/// left" or "That join code is not right". The message says why.
final class RejectedFailure extends Failure {
  const RejectedFailure(super.message);
}

final class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure([super.message = 'Please log in again.']);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong. Please try again.']);
}
