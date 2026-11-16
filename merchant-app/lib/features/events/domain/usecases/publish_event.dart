import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event.dart';
import '../repositories/events_repository.dart';

/// Publishes an event so it goes on sale in the Pin user app.
class PublishEvent implements UseCase<Event, EventDraft> {
  const PublishEvent(this._repository);

  final EventsRepository _repository;

  @override
  Future<Result<Event>> call(EventDraft params) => _repository.publishEvent(params);
}
