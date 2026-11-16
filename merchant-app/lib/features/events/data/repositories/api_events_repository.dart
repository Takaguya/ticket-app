import 'package:flutter/foundation.dart';

import '../../../../core/error/guard.dart';
import '../../../../core/network/polled_resource.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../datasources/events_api_data_source.dart';

/// [EventsRepository] answered by the Pin API. The list is polled while a
/// screen watches it; a published event shows at once.
class ApiEventsRepository implements EventsRepository {
  ApiEventsRepository(this._api, {Duration pollEvery = const Duration(seconds: 30)})
    : _events = PolledResource(fetch: _api.fetchEvents, interval: pollEvery, equals: listEquals);

  final EventsApiDataSource _api;
  final PolledResource<List<Event>> _events;

  @override
  Stream<List<Event>> watchEvents() => _events.watch();

  @override
  Future<Result<Event>> publishEvent(EventDraft draft) {
    return guard(() async {
      final event = await _api.publishEvent(draft);
      _events.update((events) => [...events, event]);
      return event;
    });
  }

  @override
  Future<Result<Event>> publishBusTrip(TripDraft draft) {
    return guard(() async {
      final event = await _api.publishBusTrip(draft);
      _events.update((events) => [...events, event]);
      return event;
    });
  }

  @override
  Future<Result<Event>> publishPlace(PlaceDraft draft) {
    return guard(() async {
      final event = await _api.publishPlace(draft);
      _events.update((events) => [...events, event]);
      return event;
    });
  }

  @override
  Future<Result<Event>> publishScreening(ScreeningDraft draft) {
    return guard(() async {
      final event = await _api.publishScreening(draft);
      _events.update((events) => [...events, event]);
      return event;
    });
  }

  @override
  Future<Result<String>> setEventImage(String eventId, Uint8List photo) {
    return guard(() async {
      final url = await _api.putImage(eventId, photo);
      _showImage(eventId, url);
      return url;
    });
  }

  @override
  Future<Result<void>> removeEventImage(String eventId) {
    return guard(() async {
      await _api.deleteImage(eventId);
      _showImage(eventId, null);
    });
  }

  /// Lists show the event's new picture (or none) at once, without waiting for the next poll.
  void _showImage(String eventId, String? url) {
    _events.update(
      (events) => [
        for (final event in events) event.id == eventId ? event.withImageUrl(url) : event,
      ],
    );
  }
}
