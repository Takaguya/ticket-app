/// Exceptions thrown by data sources. Repositories turn them into `Failure`s,
/// so nothing above the data layer catches these.
library;

/// The server answered with an error.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode});

  /// Machine-readable code from the API, e.g. `invalid_code`.
  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// The server could not be reached.
class NetworkException implements Exception {
  const NetworkException([this.message = 'No connection']);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// Known API error codes.
abstract final class ApiErrorCodes {
  static const invalidCode = 'invalid_code';
  static const invalidRegistration = 'invalid_registration';
  static const unauthorized = 'unauthorized';

  /// A business rule said no. The message is written for the person.
  static const rejected = 'rejected';

  /// The server's database is down for a moment. The message is written for the person.
  static const unavailable = 'unavailable';
}
