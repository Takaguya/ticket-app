import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event.dart';
import '../repositories/events_repository.dart';

/// Publishes a place that is open every day so its tickets go on sale in the
/// Pin user app.
class PublishPlace implements UseCase<Event, PlaceDraft> {
  const PublishPlace(this._repository);

  final EventsRepository _repository;

  @override
  Future<Result<Event>> call(PlaceDraft params) => _repository.publishPlace(params);
}
