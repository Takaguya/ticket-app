import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../models/event_json.dart';

/// The event endpoints of the Pin API. Throws `ApiException` or
/// `NetworkException`.
class EventsApiDataSource {
  const EventsApiDataSource(this._dio);

  final Dio _dio;

  /// `GET /merchant/events`: the business's events, earliest first.
  Future<List<Event>> fetchEvents() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/merchant/events');
      return [for (final json in response.data!) _event(json as Map<String, dynamic>)];
    });
  }

  /// `POST /merchant/events`. Owner only.
  Future<Event> publishEvent(EventDraft draft) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/events',
        data: EventJson.draft(draft),
      );
      return _event(response.data!);
    });
  }

  /// `POST /merchant/events/bus-trips`. Owner of a bus company only.
  Future<Event> publishBusTrip(TripDraft draft) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/events/bus-trips',
        data: EventJson.trip(draft),
      );
      return _event(response.data!);
    });
  }

  /// `POST /merchant/events/places`. Owner of an admission business only.
  Future<Event> publishPlace(PlaceDraft draft) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/events/places',
        data: EventJson.place(draft),
      );
      return _event(response.data!);
    });
  }

  /// `POST /merchant/events/screenings`. Owner of a cinema only.
  Future<Event> publishScreening(ScreeningDraft draft) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/events/screenings',
        data: EventJson.screening(draft),
      );
      return _event(response.data!);
    });
  }

  /// `PUT /merchant/events/{id}/image`: the photo is the request body as it is,
  /// not JSON or a form. Owner only. Returns the image's full address.
  Future<String> putImage(String eventId, Uint8List photo) {
    return apiCall(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/merchant/events/$eventId/image',
        // A stream is sent untouched; the length must then be said.
        data: Stream.value(photo),
        options: Options(
          contentType: 'application/octet-stream',
          headers: {Headers.contentLengthHeader: photo.length},
        ),
      );
      return _absolute(response.data!['imageUrl'] as String)!;
    });
  }

  /// `DELETE /merchant/events/{id}/image`. Owner only.
  Future<void> deleteImage(String eventId) {
    return apiCall(() async {
      await _dio.delete<void>('/merchant/events/$eventId/image');
    });
  }

  /// The event, with its image address made complete: the server sends a path
  /// on itself, and the app fetches it from the server it talks to.
  Event _event(Map<String, dynamic> json) {
    final event = EventJson.event(json);
    return event.imageUrl == null ? event : event.withImageUrl(_absolute(event.imageUrl));
  }

  String? _absolute(String? path) {
    if (path == null || path.startsWith('http')) return path;
    final base = _dio.options.baseUrl;
    return '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path';
  }
}
