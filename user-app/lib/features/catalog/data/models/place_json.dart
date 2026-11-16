import '../../domain/entities/listing.dart';
import '../../domain/entities/place_availability.dart';
import '../../domain/entities/ticket_tier.dart';

/// Places open every day (temple parks, water parks...) as the Pin API sends
/// them: in the catalogue, as the event inside a booking and what is left of a
/// day's limits. Money is whole US cents.
///
/// A place is booked by choosing a day and tickets by type. The server calls
/// the id of a place the event ID, which is what an order sends.
abstract final class PlaceJson {
  /// `GET /catalog/places`: `{id, name, venue, venueDetail, about, organiser,
  /// policy, ticketTypes: [{name, description, priceCents, dailyLimit}]}`.
  /// The event inside a booking, and `GET /catalog/events/{id}` for a place,
  /// have the same fields.
  static AdmissionListing listing(Map<String, dynamic> json) {
    return AdmissionListing(
      id: json['id'] as String,
      name: json['name'] as String,
      venue: json['venue'] as String,
      venueDetail: json['venueDetail'] as String? ?? '',
      about: json['about'] as String? ?? '',
      organiser: json['organiser'] as String? ?? '',
      policy: json['policy'] as String? ?? '',
      tiers: [
        for (final tier in json['ticketTypes'] as List<dynamic>) _tier(tier as Map<String, dynamic>),
      ],
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// `GET /catalog/places/{id}/availability`: `{date, ticketTypes: [{name,
  /// left}]}`, with `left` null for a ticket type with no limit.
  static PlaceAvailability availability(Map<String, dynamic> json) {
    return PlaceAvailability({
      for (final ticket in json['ticketTypes'] as List<dynamic>)
        if ((ticket as Map<String, dynamic>)['left'] != null)
          ticket['name'] as String: (ticket['left'] as num).toInt(),
    });
  }

  static TicketTier _tier(Map<String, dynamic> json) {
    return TicketTier(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceCents: (json['priceCents'] as num).toInt(),
    );
  }
}
