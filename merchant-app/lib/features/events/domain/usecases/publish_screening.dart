import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event.dart';
import '../repositories/events_repository.dart';

/// Publishes a cinema screening so its seats go on sale in the Pin user app.
class PublishScreening implements UseCase<Event, ScreeningDraft> {
  const PublishScreening(this._repository);

  final EventsRepository _repository;

  @override
  Future<Result<Event>> call(ScreeningDraft params) => _repository.publishScreening(params);
}
