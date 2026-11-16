import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';

/// Events as the Pin API sends and receives them:
///
/// ```json
/// {"id": "...", "name": "Kampot River Run 2026", "startsAt": "2026-11-20T06:00:00",
///  "venue": "Old Bridge, Kampot", "kind": "marathon", "commissionRate": 5.0, "capacity": 450,
///  "approved": true, "ticketTypes": [{"name": "5K", "priceCents": 1000, "quantity": 150}]}
/// ```
///
/// `startsAt` is the local time at the venue without an offset, so it is read
/// and written as a local [DateTime] with the same fields. `approved` is false
/// while Pin reviews a new event; servers that do not send it approve at once.
/// `imageUrl` is where the event's cover image is on the server (a path such as
/// `/images/events/<id>?v=1763300000000`), or null when it has none.
/// `kind` is `marathon`, `concert`, `show`, `bus`, `cinema` or `admission` (a
/// place open every day, whose ticket types' `quantity` is a limit per day); a missing one reads as a concert.
/// A bus trip also has `"bus": {"origin": "Phnom Penh", "destination": "Kampot",
/// "durationMinutes": 210, "coachType": "seater", "amenities": ["A/C"]}`.
/// A cinema screening (`"kind": "cinema"`) has `"screening": {"filmTitle": "Skyline Run",
/// "rating": "PG-13", "genre": "Action", "runtimeMinutes": 128, "hall": "Hall 2",
/// "hallSize": "large", "hallLabel": "Large hall · 120 seats", "seats": 120}`.
abstract final class EventJson {
  static Event event(Map<String, dynamic> json) {
    final bus = json['bus'] as Map<String, dynamic>?;
    final screening = json['screening'] as Map<String, dynamic>?;
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      venue: json['venue'] as String,
      ticketTypes: [
        for (final type in json['ticketTypes'] as List<dynamic>)
          ticketType(type as Map<String, dynamic>),
      ],
      kind: EventKind.fromCode(json['kind'] as String?) ?? EventKind.concert,
      bus: bus == null
          ? null
          : BusDetails(
              origin: bus['origin'] as String,
              destination: bus['destination'] as String,
              durationMinutes: (bus['durationMinutes'] as num).toInt(),
              // A coach this app does not know must not break the whole list.
              coach: CoachType.fromCode(bus['coachType'] as String?) ?? CoachType.seater,
              amenities: [for (final item in bus['amenities'] as List<dynamic>? ?? const []) item as String],
            ),
      screening: screening == null
          ? null
          : ScreeningDetails(
              filmTitle: screening['filmTitle'] as String,
              runtimeMinutes: (screening['runtimeMinutes'] as num).toInt(),
              hall: screening['hall'] as String,
              // A hall size this app does not know must not break the whole list.
              hallSize: HallSize.fromCode(screening['hallSize'] as String?) ?? HallSize.standard,
              rating: screening['rating'] as String? ?? '',
              genre: screening['genre'] as String? ?? '',
            ),
      commissionRate: (json['commissionRate'] as num).toDouble(),
      approved: json['approved'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// The body of `POST /merchant/events/bus-trips`. Empty optional texts are left out.
  static Map<String, dynamic> trip(TripDraft draft) {
    return {
      'origin': draft.origin,
      'destination': draft.destination,
      'startsAt': localDateTime(draft.startsAt),
      'durationMinutes': draft.durationMinutes,
      'coachType': draft.coach.code,
      'priceCents': draft.priceCents,
      'boardingPoint': draft.boardingPoint,
      if (draft.boardingAddress.isNotEmpty) 'boardingAddress': draft.boardingAddress,
      if (draft.about.isNotEmpty) 'about': draft.about,
      'amenities': draft.amenities,
    };
  }

  /// The body of `POST /merchant/events/screenings`. Empty optional texts are left out.
  static Map<String, dynamic> screening(ScreeningDraft draft) {
    return {
      'filmTitle': draft.filmTitle,
      'runtimeMinutes': draft.runtimeMinutes,
      'theatre': draft.theatre,
      'hall': draft.hall,
      'hallSize': draft.hallSize.code,
      'startsAt': localDateTime(draft.startsAt),
      'priceCents': draft.priceCents,
      if (draft.rating.isNotEmpty) 'rating': draft.rating,
      if (draft.genre.isNotEmpty) 'genre': draft.genre,
      if (draft.about.isNotEmpty) 'about': draft.about,
      if (draft.theatreArea.isNotEmpty) 'theatreArea': draft.theatreArea,
    };
  }

  /// The body of `POST /merchant/events/places`. Empty optional texts and
  /// unlimited tickets are left out.
  static Map<String, dynamic> place(PlaceDraft draft) {
    return {
      'name': draft.name,
      'venue': draft.venue,
      if (draft.venueDetail.isNotEmpty) 'venueDetail': draft.venueDetail,
      if (draft.about.isNotEmpty) 'about': draft.about,
      if (draft.policy.isNotEmpty) 'policy': draft.policy,
      'ticketTypes': [
        for (final ticket in draft.tickets)
          {
            'name': ticket.name,
            'priceCents': ticket.priceCents,
            if (ticket.description.isNotEmpty) 'description': ticket.description,
            if (ticket.dailyLimit != null) 'dailyLimit': ticket.dailyLimit,
          },
      ],
    };
  }

  static TicketType ticketType(Map<String, dynamic> json) {
    return TicketType(
      name: json['name'] as String,
      priceCents: (json['priceCents'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
    );
  }

  /// The body of `POST /merchant/events`.
  static Map<String, dynamic> draft(EventDraft draft) {
    return {
      'name': draft.name,
      'startsAt': localDateTime(draft.startsAt),
      'venue': draft.venue,
      'kind': draft.kind?.code,
      'ticketTypes': [
        for (final type in draft.ticketTypes)
          {'name': type.name, 'priceCents': type.priceCents, 'quantity': type.quantity},
      ],
    };
  }

  /// `2026-11-28T06:00:00`: the date and time fields, without an offset.
  static String localDateTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year.toString().padLeft(4, '0')}-${two(time.month)}-${two(time.day)}'
        'T${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
