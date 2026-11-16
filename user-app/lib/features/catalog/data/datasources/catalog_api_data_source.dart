import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/bus_departure.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/place_availability.dart';
import '../../domain/entities/showtime.dart';
import '../models/bus_json.dart';
import '../models/cinema_json.dart';
import '../models/event_json.dart';
import '../models/place_json.dart';

/// The catalogue endpoints of the Pin API. Throws `ApiException` or
/// `NetworkException`.
class CatalogApiDataSource {
  const CatalogApiDataSource(this._dio);

  final Dio _dio;

  /// `GET /catalog/events`: events on sale, soonest first.
  Future<List<EventListing>> fetchEvents() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/catalog/events');
      return [for (final json in response.data!) EventJson.listing(json as Map<String, dynamic>)];
    });
  }

  /// `GET /catalog/events/{id}`; 404 when it is not on sale (any more). A place
  /// (`kind` `admission`) has an event id too, and comes back as a place.
  Future<Listing> fetchEvent(String id) {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/catalog/events/${Uri.encodeComponent(id)}');
      final json = response.data!;
      return json['kind'] == 'admission' ? PlaceJson.listing(json) : EventJson.listing(json);
    });
  }

  /// `GET /catalog/places`: the places open every day that are on sale.
  Future<List<AdmissionListing>> fetchPlaces() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/catalog/places');
      return [for (final json in response.data!) PlaceJson.listing(json as Map<String, dynamic>)];
    });
  }

  /// `GET /catalog/places/{id}/availability`: what is left of each ticket
  /// type's limit on [date]'s day.
  Future<PlaceAvailability> fetchPlaceAvailability({required String placeId, required DateTime date}) {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/catalog/places/${Uri.encodeComponent(placeId)}/availability',
        queryParameters: {'date': _day(date)},
      );
      return PlaceJson.availability(response.data!);
    });
  }

  /// `GET /catalog/bus/routes`: the routes with a trip on sale, the busiest first.
  Future<List<BusRoute>> fetchBusRoutes() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/catalog/bus/routes');
      return [for (final json in response.data!) BusJson.route(json as Map<String, dynamic>)];
    });
  }

  /// `GET /catalog/bus/departures`: the trips from [origin] to [destination] on
  /// [date]'s day that have not left yet, earliest first.
  Future<List<BusDeparture>> fetchBusDepartures({
    required String origin,
    required String destination,
    required DateTime date,
  }) {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/catalog/bus/departures',
        queryParameters: {'origin': origin, 'destination': destination, 'date': _day(date)},
      );
      return [for (final json in response.data!) BusJson.departure(json as Map<String, dynamic>)];
    });
  }

  /// `GET /catalog/cinema/films`: the films with a screening on sale, the one
  /// showing soonest first.
  Future<List<FilmListing>> fetchFilms() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/catalog/cinema/films');
      return [for (final json in response.data!) CinemaJson.film(json as Map<String, dynamic>)];
    });
  }

  /// `GET /catalog/cinema/films/{id}`; 404 when it has no screening on sale.
  Future<FilmListing> fetchFilm(String id) {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/catalog/cinema/films/${Uri.encodeComponent(id)}');
      return CinemaJson.film(response.data!);
    });
  }

  /// `GET /catalog/cinema/films/{id}/showtimes`: the screenings on [date]'s day
  /// that have not started, by cinema.
  Future<List<TheatreShowtimes>> fetchShowtimes({required String filmId, required DateTime date}) {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/catalog/cinema/films/${Uri.encodeComponent(filmId)}/showtimes',
        queryParameters: {'date': _day(date)},
      );
      return [for (final json in response.data!) CinemaJson.theatreShowtimes(json as Map<String, dynamic>)];
    });
  }

  /// `2026-11-28`: the date as the server reads a day.
  static String _day(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
  }
}
