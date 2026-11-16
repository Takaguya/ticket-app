import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../../../mock_backend/mock_merchant_backend.dart';
import '../../../../mock_backend/mock_request_context.dart';
import '../../domain/entities/team.dart';
import '../../domain/repositories/staff_repository.dart';

/// [StaffRepository] answered by the in-memory mock backend. Replaced by an
/// API-backed implementation once the server exists.
class MockStaffRepository implements StaffRepository {
  const MockStaffRepository({required this._backend, required this._context});

  final MockMerchantBackend _backend;
  final MockRequestContext _context;

  @override
  Stream<Team> watchTeam() async* {
    final user = await _context.user();
    if (user == null) return;
    yield* _backend.watchTeam(user.businessId);
  }

  @override
  Future<Result<void>> removeMember(String memberId) {
    return guard(() async {
      final owner = await _context.requireOwner();
      await _backend.removeMember(owner.businessId, memberId);
    });
  }

  @override
  Future<Result<String>> regenerateJoinCode() {
    return guard(() async {
      final owner = await _context.requireOwner();
      return _backend.regenerateJoinCode(owner.businessId);
    });
  }
}
