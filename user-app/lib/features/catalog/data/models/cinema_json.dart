import '../../domain/entities/listing.dart';
import '../../domain/entities/showtime.dart';

/// Films and screenings as the Pin API sends them: the films showing, a film's
/// showtimes by cinema and, inside a booking, the screening it is for. Money is
/// whole US cents; `startsAt` is local time without an offset.
///
/// A screening is booked by choosing seats. The server calls the id of a
/// showtime the event ID, which is what an order sends. Its seats come as a
/// bus's do (see `BusJson.seatMap`).
abstract final class CinemaJson {
  /// `GET /catalog/cinema/films`: `{id, name, rating, genre, runtimeMinutes,
  /// about, policy, fromPriceCents, firstShowingOn}`.
  static FilmListing film(Map<String, dynamic> json) {
    return FilmListing(
      id: json['id'] as String,
      name: json['name'] as String,
      rating: json['rating'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      runtime: Duration(minutes: (json['runtimeMinutes'] as num).toInt()),
      releasedOn: DateTime.parse(json['firstShowingOn'] as String),
      about: json['about'] as String? ?? '',
      policy: json['policy'] as String? ?? '',
      fromPriceCents: (json['fromPriceCents'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// `GET /catalog/cinema/films/{id}/showtimes`: `[{theatre: {id, name, area},
  /// showtimes: [{id, startsAt, hall, priceCents, seatsLeft}]}]`.
  static TheatreShowtimes theatreShowtimes(Map<String, dynamic> json) {
    final theatre = json['theatre'] as Map<String, dynamic>;
    return TheatreShowtimes(
      theatre: Theatre(
        id: theatre['id'] as String,
        name: theatre['name'] as String,
        area: theatre['area'] as String? ?? '',
      ),
      showtimes: [
        for (final item in json['showtimes'] as List<dynamic>) showtime(item as Map<String, dynamic>),
      ],
    );
  }

  static Showtime showtime(Map<String, dynamic> json) {
    return Showtime(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      hall: json['hall'] as String,
      priceCents: (json['priceCents'] as num).toInt(),
    );
  }

  /// The film inside a booking's event: its name is the event's, the rest is in
  /// `screening` (`{filmId, rating, genre, runtimeMinutes, hall, hallSize,
  /// hallLabel}`). A booking does not say when the film first showed, so that is
  /// the screening's own day.
  static FilmListing filmOfBooking(Map<String, dynamic> event) {
    final screening = event['screening'] as Map<String, dynamic>;
    final tickets = event['ticketTypes'] as List<dynamic>;
    return FilmListing(
      id: screening['filmId'] as String,
      name: event['name'] as String,
      rating: screening['rating'] as String? ?? '',
      genre: screening['genre'] as String? ?? '',
      runtime: Duration(minutes: (screening['runtimeMinutes'] as num).toInt()),
      releasedOn: DateTime.parse(event['startsAt'] as String),
      about: event['about'] as String? ?? '',
      policy: event['policy'] as String? ?? '',
      fromPriceCents: tickets.isEmpty ? 0 : ((tickets.first as Map<String, dynamic>)['priceCents'] as num).toInt(),
      imageUrl: event['imageUrl'] as String?,
    );
  }

  /// The cinema inside a booking's event: the venue is its name, the venue's
  /// detail where it is.
  static Theatre theatreOfBooking(Map<String, dynamic> event) {
    final venue = event['venue'] as String;
    return Theatre(id: slug(venue), name: venue, area: event['venueDetail'] as String? ?? '');
  }

  /// The screening inside a booking's event.
  static Showtime showtimeOfBooking(Map<String, dynamic> event) {
    final screening = event['screening'] as Map<String, dynamic>;
    final tickets = event['ticketTypes'] as List<dynamic>;
    return Showtime(
      id: event['id'] as String,
      startsAt: DateTime.parse(event['startsAt'] as String),
      hall: screening['hall'] as String,
      priceCents: tickets.isEmpty ? 0 : ((tickets.first as Map<String, dynamic>)['priceCents'] as num).toInt(),
    );
  }

  /// `legend-cinema-aeon-mall`: the same name the server gives a cinema.
  static String slug(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
