import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../../../mock_backend/mock_catalog.dart';
import '../../domain/entities/bus_departure.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/place_availability.dart';
import '../../domain/entities/showtime.dart';
import '../../domain/entities/ticket_category.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Answers from the in-memory [MockCatalog], with a short delay so loading
/// states show as they will with the real server.
class MockCatalogRepository implements CatalogRepository {
  MockCatalogRepository({
    required this._catalog,
    this.latency = const Duration(milliseconds: 400),
  });

  final MockCatalog _catalog;

  /// Simulated network delay.
  final Duration latency;

  @override
  Future<Result<List<Listing>>> listings({TicketCategory? category}) {
    return _answer(() => _catalog.inCategory(category));
  }

  @override
  Future<Result<Listing>> listing(String id) {
    return _answer(() {
      final listing = _catalog.byId(id);
      if (listing == null) {
        throw const ApiException(
          code: ApiErrorCodes.notFound,
          message: 'This is no longer on sale.',
          statusCode: 404,
        );
      }
      return listing;
    });
  }

  @override
  Future<Result<List<Listing>>> search(String query) => _answer(() => _catalog.search(query));

  @override
  Future<Result<List<BusDeparture>>> busDepartures({
    required String origin,
    required String destination,
    required DateTime date,
  }) {
    return _answer(
      () => _catalog.departures(origin: origin, destination: destination, date: date),
    );
  }

  @override
  Future<Result<List<TheatreShowtimes>>> showtimes({
    required String filmId,
    required DateTime date,
  }) {
    return _answer(() => _catalog.showtimes(filmId: filmId, date: date));
  }

  /// The mock's places have no daily limits.
  @override
  Future<Result<PlaceAvailability>> placeAvailability({
    required String placeId,
    required DateTime date,
  }) {
    return _answer(() => PlaceAvailability.unlimited);
  }

  Future<Result<T>> _answer<T>(T Function() read) {
    return guard(() async {
      await Future<void>.delayed(latency);
      return read();
    });
  }
}
