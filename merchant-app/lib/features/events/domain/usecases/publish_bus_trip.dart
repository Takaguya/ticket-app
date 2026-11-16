import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/event.dart';
import '../repositories/events_repository.dart';

/// Publishes a bus trip so its seats go on sale in the Pin user app.
class PublishBusTrip implements UseCase<Event, TripDraft> {
  const PublishBusTrip(this._repository);

  final EventsRepository _repository;

  @override
  Future<Result<Event>> call(TripDraft params) => _repository.publishBusTrip(params);
}
