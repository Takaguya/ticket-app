import 'package:equatable/equatable.dart';

import '../../../../core/utils/date_format.dart';
import '../../../catalog/domain/entities/bus_departure.dart';
import '../../../catalog/domain/entities/listing.dart';
import '../../../catalog/domain/entities/showtime.dart';
import '../../../catalog/domain/entities/ticket_category.dart';
import '../../../catalog/domain/entities/ticket_tier.dart';
import 'order_line.dart';
import 'runner_details.dart';
import 'seat_map.dart';
import 'snack.dart';

/// What the person is about to pay for. The booking pages build it step by
/// step (tickets, seats, snacks, a runner) and checkout sends it with the
/// payment. Each category is booked differently, so each has its own kind.
sealed class BookingRequest extends Equatable {
  const BookingRequest();

  /// The event, place or film, or the route: "Phnom Penh → Siem Reap".
  String get title;
  TicketCategory get category;

  /// The cover image's path on the Pin server, or null when there is none.
  String? get imageUrl;

  /// When the event, the bus or the film starts. For a place, the start of
  /// the day chosen: the tickets are good all that day.
  DateTime get startsAt;

  /// Where to go: the venue, the cinema or the bus station.
  String get place;

  /// More about [place]: its street or area, or the cinema hall.
  String get placeDetail;

  List<OrderLine> get lines;

  /// Snacks and other extras are not tickets.
  int get ticketCount =>
      lines.where((line) => line.isTicket).fold(0, (sum, line) => sum + line.quantity);

  int get subtotalCents => lines.fold(0, (sum, line) => sum + line.totalCents);

  static List<OrderLine> _tierLines(List<TicketTier> tiers, Map<TicketTier, int> quantities) {
    return [
      for (final tier in tiers)
        if ((quantities[tier] ?? 0) > 0)
          OrderLine(name: tier.name, quantity: quantities[tier]!, unitPriceCents: tier.priceCents),
    ];
  }

  static List<OrderLine> _seatLines(List<Seat> seats, int priceCents) {
    if (seats.isEmpty) return const [];
    final ids = seats.map((seat) => seat.id).join(', ');
    return [
      OrderLine(
        name: '${seats.length == 1 ? 'Seat' : 'Seats'} $ids',
        quantity: seats.length,
        unitPriceCents: priceCents,
      ),
    ];
  }
}

/// Tickets to an event, by kind. A race also names its runner.
final class EventRequest extends BookingRequest {
  const EventRequest({required this.event, required this.quantities, this.runner});

  final EventListing event;

  /// How many of each kind. Kinds left out, or at 0, are not bought.
  final Map<TicketTier, int> quantities;

  /// Set before checkout when [EventListing.needsRunnerDetails].
  final RunnerDetails? runner;

  EventRequest withRunner(RunnerDetails runner) {
    return EventRequest(event: event, quantities: quantities, runner: runner);
  }

  @override
  String get title => event.name;

  @override
  String? get imageUrl => event.imageUrl;

  @override
  TicketCategory get category => TicketCategory.events;

  @override
  DateTime get startsAt => event.startsAt;

  @override
  String get place => event.venue;

  @override
  String get placeDetail => event.venueDetail;

  @override
  List<OrderLine> get lines => BookingRequest._tierLines(event.tiers, quantities);

  @override
  List<Object?> get props => [event, quantities, runner];
}

/// Tickets to a place for one day.
final class AdmissionRequest extends BookingRequest {
  const AdmissionRequest({required this.attraction, required this.day, required this.quantities});

  final AdmissionListing attraction;

  /// Only the date counts.
  final DateTime day;

  /// How many of each kind. Kinds left out, or at 0, are not bought.
  final Map<TicketTier, int> quantities;

  @override
  String get title => attraction.name;

  @override
  String? get imageUrl => attraction.imageUrl;

  @override
  TicketCategory get category => TicketCategory.admission;

  @override
  DateTime get startsAt => DateFormat.dateOnly(day);

  @override
  String get place => attraction.venue;

  @override
  String get placeDetail => attraction.venueDetail;

  @override
  List<OrderLine> get lines => BookingRequest._tierLines(attraction.tiers, quantities);

  @override
  List<Object?> get props => [attraction, day, quantities];
}

/// Seats on one bus.
final class BusRequest extends BookingRequest {
  const BusRequest({required this.departure, this.seats = const []});

  final BusDeparture departure;
  final List<Seat> seats;

  BusRequest withSeats(List<Seat> seats) => BusRequest(departure: departure, seats: seats);

  @override
  String get title => '${departure.origin} → ${departure.destination}';

  @override
  String? get imageUrl => departure.imageUrl;

  @override
  TicketCategory get category => TicketCategory.bus;

  @override
  DateTime get startsAt => departure.departsAt;

  @override
  String get place => departure.boardingPoint;

  @override
  String get placeDetail => departure.boardingAddress;

  @override
  List<OrderLine> get lines => BookingRequest._seatLines(seats, departure.priceCents);

  @override
  List<Object?> get props => [departure, seats];
}

/// Seats at one screening, and snacks to pick up at the counter.
final class CinemaRequest extends BookingRequest {
  const CinemaRequest({
    required this.film,
    required this.theatre,
    required this.showtime,
    this.seats = const [],
    this.snacks = const {},
  });

  final FilmListing film;
  final Theatre theatre;
  final Showtime showtime;
  final List<Seat> seats;

  /// How many of each. Snacks left out, or at 0, are not bought.
  final Map<Snack, int> snacks;

  CinemaRequest withSeats(List<Seat> seats) {
    return CinemaRequest(film: film, theatre: theatre, showtime: showtime, seats: seats, snacks: snacks);
  }

  CinemaRequest withSnacks(Map<Snack, int> snacks) {
    return CinemaRequest(film: film, theatre: theatre, showtime: showtime, seats: seats, snacks: snacks);
  }

  @override
  String get title => film.name;

  @override
  String? get imageUrl => film.imageUrl;

  @override
  TicketCategory get category => TicketCategory.cinema;

  @override
  DateTime get startsAt => showtime.startsAt;

  @override
  String get place => theatre.name;

  @override
  String get placeDetail => showtime.hall;

  @override
  List<OrderLine> get lines => [
    ...BookingRequest._seatLines(seats, showtime.priceCents),
    for (final MapEntry(key: snack, value: quantity) in snacks.entries)
      if (quantity > 0)
        OrderLine(
          name: snack.name,
          quantity: quantity,
          unitPriceCents: snack.priceCents,
          isTicket: false,
        ),
  ];

  @override
  List<Object?> get props => [film, theatre, showtime, seats, snacks];
}
