import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/events_repository.dart';

/// Takes the cover image off an event (by the event's ID).
class RemoveEventImage implements UseCase<void, String> {
  const RemoveEventImage(this._repository);

  final EventsRepository _repository;

  @override
  Future<Result<void>> call(String params) => _repository.removeEventImage(params);
}
