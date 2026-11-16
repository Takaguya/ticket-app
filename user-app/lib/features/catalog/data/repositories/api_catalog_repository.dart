import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/bus_departure.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/place_availability.dart';
import '../../domain/entities/showtime.dart';
import '../../domain/entities/ticket_category.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_api_data_source.dart';

/// [CatalogRepository] answered by the Pin API, which sells events, bus trips,
/// cinema screenings and places.
///
/// A bus trip is a one-off tour to a province on a date, so a route is listed
/// while it has a trip on sale and a day with no trip simply has no buses. A
/// screening is one showing of a film: a film is listed while it has a
/// screening on sale, and a day with none has no showtimes. A place is open
/// every day: it is listed once approved, and each kind of ticket can have a
/// limit per day.
class ApiCatalogRepository implements CatalogRepository {
  const ApiCatalogRepository(this._api);

  final CatalogApiDataSource _api;

  /// An event's or a place's id is a UUID; a film's is its title as a word list.
  static final _eventId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  Future<Result<List<Listing>>> listings({TicketCategory? category}) {
    return switch (category) {
      TicketCategory.events => guard<List<Listing>>(_api.fetchEvents),
      TicketCategory.bus => guard<List<Listing>>(_api.fetchBusRoutes),
      TicketCategory.cinema => guard<List<Listing>>(_api.fetchFilms),
      TicketCategory.admission => guard<List<Listing>>(_api.fetchPlaces),
      // Everything on sale: events soonest first, then the bus routes, the films and the places.
      null => guard<List<Listing>>(
        () async => [
          ...await _api.fetchEvents(),
          ...await _api.fetchBusRoutes(),
          ...await _api.fetchFilms(),
          ...await _api.fetchPlaces(),
        ],
      ),
    };
  }

  @override
  Future<Result<Listing>> listing(String id) {
    return guard<Listing>(() => _eventId.hasMatch(id) ? _api.fetchEvent(id) : _api.fetchFilm(id));
  }

  /// The server has no search yet: the app filters the events, routes, films
  /// and places it has by name, venue and where the venue is.
  @override
  Future<Result<List<Listing>>> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return Future.value(const Result.success([]));
    return guard<List<Listing>>(() async {
      final events = await _api.fetchEvents();
      final routes = await _api.fetchBusRoutes();
      final films = await _api.fetchFilms();
      final places = await _api.fetchPlaces();
      return [
        for (final event in events)
          if ('${event.name} ${event.venue} ${event.venueDetail}'.toLowerCase().contains(needle)) event,
        for (final route in routes)
          if (route.name.toLowerCase().contains(needle)) route,
        for (final film in films)
          if ('${film.name} ${film.genre}'.toLowerCase().contains(needle)) film,
        for (final place in places)
          if ('${place.name} ${place.venue} ${place.venueDetail}'.toLowerCase().contains(needle)) place,
      ];
    });
  }

  @override
  Future<Result<List<BusDeparture>>> busDepartures({
    required String origin,
    required String destination,
    required DateTime date,
  }) {
    return guard(() => _api.fetchBusDepartures(origin: origin, destination: destination, date: date));
  }

  @override
  Future<Result<List<TheatreShowtimes>>> showtimes({
    required String filmId,
    required DateTime date,
  }) {
    return guard(() => _api.fetchShowtimes(filmId: filmId, date: date));
  }

  @override
  Future<Result<PlaceAvailability>> placeAvailability({
    required String placeId,
    required DateTime date,
  }) {
    return guard(() => _api.fetchPlaceAvailability(placeId: placeId, date: date));
  }
}
