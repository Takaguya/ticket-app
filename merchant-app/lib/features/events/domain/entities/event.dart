import 'package:equatable/equatable.dart';

/// A kind of ticket sold for an event, e.g. "10K" at $18 with 80 for sale.
class TicketType extends Equatable {
  const TicketType({required this.name, required this.priceCents, required this.quantity});

  /// The quantity of a ticket type with no limit: the server's own, for a
  /// place's tickets per day.
  static const noLimit = 100000;

  final String name;

  /// 0 means free.
  final int priceCents;

  /// How many are for sale. For a place, how many per day.
  final int quantity;

  /// Whether there is a cap on how many can be sold (per day, for a place).
  bool get hasLimit => quantity < noLimit;

  @override
  List<Object?> get props => [name, priceCents, quantity];
}

/// Where an event sits relative to a given day.
enum EventTiming { past, today, upcoming }

/// What an event is. Buyers see it, and only a marathon asks them for runner
/// details when booking. A bus trip and a cinema screening are published by a
/// bus company and a cinema with their own forms, and are booked by choosing
/// seats. A place (a temple park, a water park) is published by an admission
/// business and is open every day: buyers pick the day they visit.
enum EventKind {
  marathon('marathon', 'Marathon'),
  concert('concert', 'Concert'),
  show('show', 'Show'),
  bus('bus', 'Bus trip'),
  cinema('cinema', 'Screening'),
  admission('admission', 'Place');

  const EventKind(this.code, this.label);

  /// What a business that sells events chooses from when it creates one.
  static const forEvents = [marathon, concert, show];

  /// How the Pin API writes it.
  final String code;

  /// How people read it.
  final String label;

  /// The kind for an API [code], or null when it is not one the app knows.
  static EventKind? fromCode(String? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// The coach of a bus trip. It decides the seats: a standard seater has 10 rows
/// of 2+2, a VIP seater 10 rows of 2+1 and a sleeper 8 rows of 1+1 beds.
enum CoachType {
  seater('seater', 'Seater · 2+2', 10, ['A', 'B', 'C', 'D']),
  vip('vip', 'VIP seater · 2+1', 10, ['A', 'B', 'C']),
  sleeper('sleeper', 'Sleeper · 1+1', 8, ['A', 'B']);

  const CoachType(this.code, this.label, this.rows, this.columns);

  /// How the Pin API writes it.
  final String code;

  /// How people read it, e.g. "Seater · 2+2".
  final String label;
  final int rows;

  /// The seat letters in a row, left to right.
  final List<String> columns;

  int get seats => rows * columns.length;

  /// Every seat, front row first, as the server names them: `1A`, `1B`, `2A`...
  List<String> get seatIds => [
    for (var row = 1; row <= rows; row++)
      for (final column in columns) '$row$column',
  ];

  /// The coach for an API [code], or null when it is not one the app knows.
  static CoachType? fromCode(String? code) {
    for (final coach in values) {
      if (coach.code == code) return coach;
    }
    return null;
  }
}

/// What makes an event a bus trip: a tour to a province.
class BusDetails extends Equatable {
  const BusDetails({
    required this.origin,
    required this.destination,
    required this.durationMinutes,
    required this.coach,
    this.amenities = const [],
  });

  final String origin;
  final String destination;
  final int durationMinutes;
  final CoachType coach;

  /// On board, e.g. Wi-Fi, A/C, Snack.
  final List<String> amenities;

  @override
  List<Object?> get props => [origin, destination, durationMinutes, coach, amenities];
}

/// The size of a cinema hall. It decides the seats, in rows lettered from the
/// screen: a small hall has 6 rows of 8, a standard hall 8 rows of 10 and a
/// large hall 10 rows of 12.
enum HallSize {
  small('small', 'Small', 6, 8),
  standard('standard', 'Standard', 8, 10),
  large('large', 'Large', 10, 12);

  const HallSize(this.code, this.name, this.rows, this.seatsPerRow);

  /// How the Pin API writes it.
  final String code;

  /// How people read it, e.g. "Standard".
  final String name;
  final int rows;
  final int seatsPerRow;

  int get seats => rows * seatsPerRow;

  /// "Standard · 80 seats"
  String get label => '$name · $seats seats';

  /// Every seat, front row first, as the server names them: `A1`, `A2`... `B1`...
  List<String> get seatIds => [
    for (var row = 0; row < rows; row++)
      for (var seat = 1; seat <= seatsPerRow; seat++) '${String.fromCharCode(65 + row)}$seat',
  ];

  /// The size for an API [code], or null when it is not one the app knows.
  static HallSize? fromCode(String? code) {
    for (final size in values) {
      if (size.code == code) return size;
    }
    return null;
  }
}

/// What makes an event a cinema screening: one showing of a film in a hall.
class ScreeningDetails extends Equatable {
  const ScreeningDetails({
    required this.filmTitle,
    required this.runtimeMinutes,
    required this.hall,
    required this.hallSize,
    this.rating = '',
    this.genre = '',
  });

  final String filmTitle;
  final int runtimeMinutes;

  /// The hall's name at the cinema, e.g. "Hall 3".
  final String hall;
  final HallSize hallSize;

  /// E.g. "PG-13". May be empty.
  final String rating;
  final String genre;

  @override
  List<Object?> get props => [filmTitle, runtimeMinutes, hall, hallSize, rating, genre];
}

/// An event published by the business. It goes on sale once Pin approves it.
class Event extends Equatable {
  const Event({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.venue,
    required this.ticketTypes,
    this.kind = EventKind.concert,
    this.bus,
    this.screening,
    this.commissionRate = 5,
    this.approved = true,
    this.imageUrl,
  });

  final String id;
  final String name;

  /// Servers that do not send a kind are read as concerts, like the backend's
  /// own default for older events.
  final EventKind kind;

  /// Set for a bus trip only.
  final BusDetails? bus;

  /// Set for a cinema screening only.
  final ScreeningDetails? screening;

  /// Start date and time, local to the venue.
  final DateTime startsAt;
  final String venue;
  final List<TicketType> ticketTypes;

  /// Percent Pin keeps of online sales. Door sales carry no commission.
  final double commissionRate;

  /// False while Pin reviews a newly published event: nothing sells until then.
  final bool approved;

  /// Where the cover image can be fetched from (a full address, with a version
  /// that changes whenever the picture does), or null when the event has none.
  final String? imageUrl;

  /// This event with a new cover image address, or with none when [imageUrl] is null.
  Event withImageUrl(String? imageUrl) => Event(
    id: id,
    name: name,
    startsAt: startsAt,
    venue: venue,
    ticketTypes: ticketTypes,
    kind: kind,
    bus: bus,
    screening: screening,
    commissionRate: commissionRate,
    approved: approved,
    imageUrl: imageUrl,
  );

  /// The most tickets that can be sold: the sum of all ticket type quantities.
  /// For a place these are limits per day, so this is not a total.
  int get capacity => ticketTypes.fold(0, (sum, type) => sum + type.quantity);

  /// A place is open every day: it has no date of its own (its [startsAt] is
  /// the day it was published), so it never ends.
  bool get isPlace => kind == EventKind.admission;

  /// Check-in is only possible while this is [EventTiming.today].
  EventTiming timingOn(DateTime now) {
    if (isPlace) return EventTiming.today;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(startsAt.year, startsAt.month, startsAt.day);
    if (day.isBefore(today)) return EventTiming.past;
    if (day.isAfter(today)) return EventTiming.upcoming;
    return EventTiming.today;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    bus,
    screening,
    startsAt,
    venue,
    ticketTypes,
    commissionRate,
    approved,
    imageUrl,
  ];
}
