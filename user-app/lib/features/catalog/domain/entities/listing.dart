import 'package:equatable/equatable.dart';

import 'event_kind.dart';
import 'ticket_category.dart';
import 'ticket_tier.dart';

/// Something Pin sells tickets for. Each category has its own kind, because
/// they are bought differently: an event on its date, a place on any day, a
/// film at a showtime, a bus route on a departure.
sealed class Listing extends Equatable {
  const Listing({required this.id});

  final String id;

  String get name;
  TicketCategory get category;

  /// Where the cover image is on the Pin server: a path such as
  /// `/images/events/<id>?v=1763300000000`. Null when the organiser has not added one
  /// (screens then show a coloured placeholder), and always null for a bus route, which
  /// is many trips of many companies.
  String? get imageUrl => null;

  /// The cheapest paid ticket, in whole US cents: what "From $x" shows.
  /// 0 when everything is free.
  int get fromPriceCents;

  /// The lowest price above zero, or 0 when there is none.
  static int lowestPaidPrice(List<TicketTier> tiers) {
    final paid = tiers.map((tier) => tier.priceCents).where((price) => price > 0);
    return paid.isEmpty ? 0 : paid.reduce((a, b) => a < b ? a : b);
  }
}

/// A one-off event on a date: a concert, a race, a comedy night.
final class EventListing extends Listing {
  const EventListing({
    required super.id,
    required this.name,
    required this.startsAt,
    required this.venue,
    required this.venueDetail,
    required this.about,
    required this.organiser,
    required this.policy,
    required this.tiers,
    required this.kind,
    this.imageUrl,
  });

  @override
  final String name;
  @override
  final String? imageUrl;
  final DateTime startsAt;
  final String venue;

  /// Where the venue is, e.g. "Diamond Island, Phnom Penh".
  final String venueDetail;
  final String about;
  final String organiser;

  /// Refunds and transfers, e.g. "Refundable up to 48h before the show".
  final String policy;
  final List<TicketTier> tiers;

  /// A marathon, a concert or a show.
  final EventKind kind;

  /// A race: each booking registers one runner, with the details the
  /// organiser needs (age, emergency contact, T-shirt size...).
  bool get needsRunnerDetails => kind.needsRunnerDetails;

  @override
  TicketCategory get category => TicketCategory.events;

  @override
  int get fromPriceCents => Listing.lowestPaidPrice(tiers);

  @override
  List<Object?> get props => [
    id,
    name,
    startsAt,
    venue,
    venueDetail,
    about,
    organiser,
    policy,
    tiers,
    kind,
    imageUrl,
  ];
}

/// A place open on any day: a temple park, a water park, a wildlife centre.
final class AdmissionListing extends Listing {
  const AdmissionListing({
    required super.id,
    required this.name,
    required this.venue,
    required this.venueDetail,
    required this.about,
    required this.organiser,
    required this.policy,
    required this.tiers,
    this.imageUrl,
  });

  @override
  final String name;
  @override
  final String? imageUrl;
  final String venue;
  final String venueDetail;
  final String about;
  final String organiser;
  final String policy;
  final List<TicketTier> tiers;

  @override
  TicketCategory get category => TicketCategory.admission;

  @override
  int get fromPriceCents => Listing.lowestPaidPrice(tiers);

  @override
  List<Object?> get props => [id, name, venue, venueDetail, about, organiser, policy, tiers, imageUrl];
}

/// A film showing in cinemas, with showtimes every day.
final class FilmListing extends Listing {
  const FilmListing({
    required super.id,
    required this.name,
    required this.rating,
    required this.genre,
    required this.runtime,
    required this.releasedOn,
    required this.about,
    required this.policy,
    required this.fromPriceCents,
    this.imageUrl,
  });

  @override
  final String name;

  /// The film's poster: the cover image of its first screening that has one.
  @override
  final String? imageUrl;

  /// Age rating, e.g. "PG-13".
  final String rating;

  /// Language or genre, e.g. "Khmer" or "Action".
  final String genre;
  final Duration runtime;
  final DateTime releasedOn;
  final String about;
  final String policy;

  @override
  final int fromPriceCents;

  @override
  TicketCategory get category => TicketCategory.cinema;

  @override
  List<Object?> get props => [id, name, rating, genre, runtime, releasedOn, about, policy, fromPriceCents, imageUrl];
}

/// A bus route, e.g. Phnom Penh → Siem Reap, served by several operators.
final class BusRoute extends Listing {
  const BusRoute({
    required super.id,
    required this.origin,
    required this.destination,
    required this.typicalDuration,
    required this.operatorCount,
    required this.fromPriceCents,
  });

  final String origin;
  final String destination;
  final Duration typicalDuration;
  final int operatorCount;

  @override
  final int fromPriceCents;

  @override
  String get name => '$origin → $destination';

  @override
  TicketCategory get category => TicketCategory.bus;

  @override
  List<Object?> get props => [id, origin, destination, typicalDuration, operatorCount, fromPriceCents];
}
