import '../../../../core/result/result.dart';
import '../entities/bus_departure.dart';
import '../entities/listing.dart';
import '../entities/place_availability.dart';
import '../entities/showtime.dart';
import '../entities/ticket_category.dart';

/// What Pin has tickets for: events, places, films and bus routes.
abstract interface class CatalogRepository {
  /// Everything on sale in [category], or in every category when null.
  /// Events come soonest first.
  Future<Result<List<Listing>>> listings({TicketCategory? category});

  /// One listing. Fails with `NotFoundFailure` when it is no longer on sale.
  Future<Result<Listing>> listing(String id);

  /// Listings whose name or place contains [query], ignoring case.
  Future<Result<List<Listing>>> search(String query);

  /// Buses from [origin] to [destination] on [date]'s day that have not left
  /// yet, earliest first.
  Future<Result<List<BusDeparture>>> busDepartures({
    required String origin,
    required String destination,
    required DateTime date,
  });

  /// Where and when the film shows on [date]'s day, without screenings that
  /// have already started.
  Future<Result<List<TheatreShowtimes>>> showtimes({
    required String filmId,
    required DateTime date,
  });

  /// What is left of each kind of ticket of a place on [date]'s day: a kind
  /// can have a limit per day.
  Future<Result<PlaceAvailability>> placeAvailability({
    required String placeId,
    required DateTime date,
  });
}
