import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/staff_repository.dart';

/// Removes a scanner from the business. Takes the member's ID.
class RemoveStaffMember implements UseCase<void, String> {
  const RemoveStaffMember(this._repository);

  final StaffRepository _repository;

  @override
  Future<Result<void>> call(String memberId) => _repository.removeMember(memberId);
}
