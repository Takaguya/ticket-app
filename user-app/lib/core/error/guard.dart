import '../result/result.dart';
import 'exceptions.dart';
import 'failure.dart';

/// Runs a data-layer [action] and turns anything it throws into a [Failure],
/// so repositories never throw.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.success(await action());
  } on Object catch (error) {
    return Result.failure(failureOf(error));
  }
}

/// The failure for anything a data source threw.
Failure failureOf(Object error) {
  return switch (error) {
    NetworkException() => const NetworkFailure(),
    ApiException() => failureFor(error),
    _ => const UnexpectedFailure(),
  };
}

/// The failure that matches an API error code.
Failure failureFor(ApiException error) {
  return switch (error.code) {
    ApiErrorCodes.invalidCode => const InvalidCodeFailure(),
    ApiErrorCodes.invalidRegistration => const SessionExpiredFailure(
      'Please confirm your phone number again.',
    ),
    ApiErrorCodes.unauthorized => const SessionExpiredFailure(),
    ApiErrorCodes.notFound => NotFoundFailure(error.message),
    ApiErrorCodes.rejected => RejectedFailure(error.message),
    ApiErrorCodes.unavailable => ServerFailure(error.message),
    _ => const ServerFailure(),
  };
}
