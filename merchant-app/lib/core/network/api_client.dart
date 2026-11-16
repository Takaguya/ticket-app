import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';

/// Reads the current access token, or null when signed out.
typedef TokenReader = Future<String?> Function();

/// The path that ends the session on the server.
const signOutPath = '/auth/sign-out';

/// Builds the HTTP client for the Pin API. Every request carries the access
/// token when one is stored.
///
/// [onSessionRejected] runs when the server refuses a stored token (401), for
/// example after the owner removed this scanner, so the app can sign out.
Dio createApiClient({
  required AppConfig config,
  required TokenReader readToken,
  void Function()? onSessionRejected,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        final request = error.requestOptions;
        final sentToken = request.headers.containsKey('Authorization');
        // Signing out with a token the server already refused must not start another sign-out.
        if (error.response?.statusCode == 401 && sentToken && request.path != signOutPath) {
          onSessionRejected?.call();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}

/// Runs an API request and turns a failure into [ApiException] or
/// [NetworkException], which repositories turn into failures.
Future<T> apiCall<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    throw mapDioException(error);
  }
}

/// Converts a Dio error into one of the app's data-layer exceptions.
///
/// The API is expected to answer errors as `{"code": "...", "message": "..."}`.
Exception mapDioException(DioException error) {
  final response = error.response;
  if (response == null) return NetworkException(error.message ?? 'No connection');

  final data = response.data;
  final body = data is Map<String, dynamic> ? data : const <String, dynamic>{};
  final unauthorized = response.statusCode == 401;
  return ApiException(
    code: body['code'] as String? ?? (unauthorized ? ApiErrorCodes.unauthorized : 'server_error'),
    message: body['message'] as String? ?? 'Request failed',
    statusCode: response.statusCode,
  );
}
