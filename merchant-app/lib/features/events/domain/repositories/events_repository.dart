import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../entities/event.dart';

/// What the owner fills in on the "Create event" screen.
class EventDraft extends Equatable {
  const EventDraft({
    required this.name,
    required this.startsAt,
    required this.venue,
    required this.ticketTypes,
    this.kind,
  });

  final String name;
  final DateTime startsAt;
  final String venue;
  final List<TicketType> ticketTypes;

  /// Required by the server, which refuses a draft without one.
  final EventKind? kind;

  @override
  List<Object?> get props => [name, kind, startsAt, venue, ticketTypes];
}

/// What the owner of a bus company fills in on the "Create trip" screen. A trip
/// is a tour to a province: one dated departure, with as many seats for sale as
/// the coach has.
class TripDraft extends Equatable {
  const TripDraft({
    required this.origin,
    required this.destination,
    required this.startsAt,
    required this.durationMinutes,
    required this.coach,
    required this.priceCents,
    required this.boardingPoint,
    this.boardingAddress = '',
    this.about = '',
    this.amenities = const [],
  });

  final String origin;
  final String destination;

  /// When the bus leaves, local time.
  final DateTime startsAt;
  final int durationMinutes;
  final CoachType coach;

  /// Per seat, in whole US cents; 0 is free.
  final int priceCents;

  /// Where to get on, e.g. a terminal.
  final String boardingPoint;
  final String boardingAddress;

  /// What the tour is about. May be empty.
  final String about;
  final List<String> amenities;

  @override
  List<Object?> get props => [
    origin,
    destination,
    startsAt,
    durationMinutes,
    coach,
    priceCents,
    boardingPoint,
    boardingAddress,
    about,
    amenities,
  ];
}

/// What the owner of a cinema fills in on the "Create screening" screen: one
/// showing of a film, with as many seats for sale as the hall has.
class ScreeningDraft extends Equatable {
  const ScreeningDraft({
    required this.filmTitle,
    required this.runtimeMinutes,
    required this.theatre,
    required this.hall,
    required this.hallSize,
    required this.startsAt,
    required this.priceCents,
    this.rating = '',
    this.genre = '',
    this.about = '',
    this.theatreArea = '',
  });

  final String filmTitle;
  final int runtimeMinutes;

  /// The cinema or branch buyers see, e.g. "Legend Cinema, Aeon Mall".
  final String theatre;

  /// Where it is, e.g. "Aeon Mall, Sihanouk Blvd". May be empty.
  final String theatreArea;

  /// The hall's name, e.g. "Hall 3".
  final String hall;
  final HallSize hallSize;

  /// When the film starts, local time.
  final DateTime startsAt;

  /// Per seat, in whole US cents; 0 is free.
  final int priceCents;
  final String rating;
  final String genre;

  /// The film's synopsis. May be empty.
  final String about;

  @override
  List<Object?> get props => [
    filmTitle,
    runtimeMinutes,
    theatre,
    theatreArea,
    hall,
    hallSize,
    startsAt,
    priceCents,
    rating,
    genre,
    about,
  ];
}

/// One kind of ticket of a place, as the owner of an admission business
/// fills it in.
class PlaceTicketDraft extends Equatable {
  const PlaceTicketDraft({
    required this.name,
    required this.priceCents,
    this.description = '',
    this.dailyLimit,
  });

  final String name;

  /// Per ticket, in whole US cents; 0 is free.
  final int priceCents;

  /// E.g. "Under 12 · ID required". May be empty.
  final String description;

  /// The most sold for one day; null for no limit.
  final int? dailyLimit;

  @override
  List<Object?> get props => [name, priceCents, description, dailyLimit];
}

/// What the owner of an admission business fills in on the "Create place"
/// screen: a place open every day, with 1 to 6 kinds of ticket. Buyers choose
/// the day they visit; there is no date.
class PlaceDraft extends Equatable {
  const PlaceDraft({
    required this.name,
    required this.venue,
    required this.tickets,
    this.venueDetail = '',
    this.about = '',
    this.policy = '',
  });

  final String name;

  /// The site, e.g. "Garden City".
  final String venue;

  /// Where it is, e.g. "Chroy Changvar, Phnom Penh". May be empty.
  final String venueDetail;

  /// What visitors find there. May be empty.
  final String about;

  /// Refunds and changes. May be empty.
  final String policy;
  final List<PlaceTicketDraft> tickets;

  @override
  List<Object?> get props => [name, venue, venueDetail, about, policy, tickets];
}

abstract interface class EventsRepository {
  /// The business's events: the current list first, then again after every
  /// change.
  Stream<List<Event>> watchEvents();

  /// Publishes an event so it goes on sale in the Pin user app. Owner only.
  Future<Result<Event>> publishEvent(EventDraft draft);

  /// Publishes a bus trip so its seats go on sale in the Pin user app. Owner of
  /// a bus company only.
  Future<Result<Event>> publishBusTrip(TripDraft draft);

  /// Publishes a cinema screening so its seats go on sale in the Pin user app.
  /// Owner of a cinema only.
  Future<Result<Event>> publishScreening(ScreeningDraft draft);

  /// Publishes a place that is open every day, so its tickets go on sale in
  /// the Pin user app. Owner of an admission business only.
  Future<Result<Event>> publishPlace(PlaceDraft draft);

  /// Sets or replaces the cover image of one of the business's events with a
  /// photo (a JPEG or PNG up to 5 MB; the server resizes it). Succeeds with the
  /// image's new address, which changes whenever the picture does. The events
  /// list shows it too. Owner only.
  Future<Result<String>> setEventImage(String eventId, Uint8List photo);

  /// Takes the cover image off one of the business's events. Owner only.
  Future<Result<void>> removeEventImage(String eventId);
}
