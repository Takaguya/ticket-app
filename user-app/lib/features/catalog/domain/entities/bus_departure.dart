import 'package:equatable/equatable.dart';

/// One bus leaving on a route at a set time, e.g. Giant Ibis at 07:45.
class BusDeparture extends Equatable {
  const BusDeparture({
    required this.id,
    required this.routeId,
    required this.operatorName,
    required this.operatorCode,
    required this.operatorColor,
    required this.coachType,
    required this.origin,
    required this.destination,
    required this.departsAt,
    required this.duration,
    required this.priceCents,
    required this.amenities,
    required this.seatsLeft,
    required this.boardingPoint,
    required this.boardingAddress,
    this.imageUrl,
  });

  final String id;
  final String routeId;
  final String operatorName;

  /// Two letters for the operator's badge, e.g. "GI".
  final String operatorCode;

  /// The operator's brand colour as 0xAARRGGBB, for its badge.
  final int operatorColor;

  /// Kind of coach and seat layout, e.g. "Luxury coach · 2+2".
  final String coachType;
  final String origin;
  final String destination;
  final DateTime departsAt;
  final Duration duration;

  /// Per seat, in whole US cents.
  final int priceCents;

  /// On board, e.g. ["Wi-Fi", "A/C", "Snack"].
  final List<String> amenities;
  final int seatsLeft;

  /// Where to get on, e.g. "Giant Ibis / Virak Buntham Terminal".
  final String boardingPoint;

  /// The street of [boardingPoint], e.g. "St 106, Riverside, Phnom Penh".
  final String boardingAddress;

  /// The trip's cover image on the Pin server (a path), or null.
  final String? imageUrl;

  DateTime get arrivesAt => departsAt.add(duration);

  /// Few enough seats to warn about.
  bool get isNearlyFull => seatsLeft <= 5;

  @override
  List<Object?> get props => [
    id,
    routeId,
    operatorName,
    operatorCode,
    operatorColor,
    coachType,
    origin,
    destination,
    departsAt,
    duration,
    priceCents,
    amenities,
    seatsLeft,
    boardingPoint,
    boardingAddress,
    imageUrl,
  ];
}
