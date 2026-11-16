import '../../domain/entities/event_kind.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/ticket_tier.dart';

/// An event as the Pin API sends it, in the catalogue and inside a booking:
/// `{id, name, startsAt, venue, venueDetail, about, organiser, policy,
/// kind, ticketTypes: [{name, description, priceCents}], imageUrl}` (`kind` is
/// `marathon`, `concert` or `show`; the server also still sends `needsRunnerDetails`).
/// `imageUrl` is the cover image's path on the server, or null.
///
/// `startsAt` is local time at the venue, without an offset, so it parses to
/// the same wall-clock time the app shows.
abstract final class EventJson {
  static EventListing listing(Map<String, dynamic> json) {
    return EventListing(
      id: json['id'] as String,
      name: json['name'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      venue: json['venue'] as String,
      venueDetail: json['venueDetail'] as String? ?? '',
      about: json['about'] as String? ?? '',
      organiser: json['organiser'] as String? ?? '',
      policy: json['policy'] as String? ?? '',
      kind: _kind(json),
      tiers: [
        for (final tier in json['ticketTypes'] as List<dynamic>) _tier(tier as Map<String, dynamic>),
      ],
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// An older server sends only `needsRunnerDetails`: a race is a marathon,
  /// anything else a concert.
  static EventKind _kind(Map<String, dynamic> json) {
    final kind = EventKind.fromCode(json['kind'] as String?);
    if (kind != null) return kind;
    return (json['needsRunnerDetails'] as bool? ?? false) ? EventKind.marathon : EventKind.concert;
  }

  static TicketTier _tier(Map<String, dynamic> json) {
    return TicketTier(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceCents: (json['priceCents'] as num).toInt(),
    );
  }
}
