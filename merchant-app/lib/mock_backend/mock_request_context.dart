import '../core/error/exceptions.dart';
import '../features/auth/domain/entities/merchant_user.dart';

/// Who is calling the mock backend. A real server learns this from the
/// access token; the mock reads the signed-in user from the device.
class MockRequestContext {
  const MockRequestContext(this._readUser);

  final Future<MerchantUser?> Function() _readUser;

  /// The signed-in user, or null when signed out.
  Future<MerchantUser?> user() => _readUser();

  Future<MerchantUser> requireUser() async {
    final user = await _readUser();
    if (user == null) {
      throw const ApiException(
        code: ApiErrorCodes.unauthorized,
        message: 'Not signed in',
        statusCode: 401,
      );
    }
    return user;
  }

  /// Door sale, create event, finance, staff and CSV are for owners only.
  Future<MerchantUser> requireOwner() async {
    final user = await requireUser();
    if (!user.isOwner) {
      throw const ApiException(
        code: ApiErrorCodes.rejected,
        message: 'Only the owner can do this.',
        statusCode: 403,
      );
    }
    return user;
  }
}
