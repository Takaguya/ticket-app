import '../result/result.dart';
import 'exceptions.dart';
import 'failure.dart';

/// Runs a data-layer [action] and turns anything it throws into a [Failure],
/// so repositories never throw.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.success(await action());
  } on NetworkException {
    return Result.failure(const NetworkFailure());
  } on ApiException catch (error) {
    return Result.failure(failureFor(error));
  } on Object {
    return Result.failure(const UnexpectedFailure());
  }
}

/// The failure that matches an API error code.
Failure failureFor(ApiException error) {
  return switch (error.code) {
    ApiErrorCodes.invalidCode => const InvalidCodeFailure(),
    ApiErrorCodes.invalidRegistration => const SessionExpiredFailure(
      'Please confirm your phone number again.',
    ),
    ApiErrorCodes.unauthorized => const SessionExpiredFailure(),
    ApiErrorCodes.rejected => RejectedFailure(error.message),
    ApiErrorCodes.unavailable => ServerFailure(error.message),
    _ => const ServerFailure(),
  };
}
