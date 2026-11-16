import '../../../booking/domain/entities/seat_map.dart';
import '../../domain/entities/bus_departure.dart';
import '../../domain/entities/listing.dart';

/// Bus trips as the Pin API sends them: routes, the trips on a route and a
/// trip's seats. Money is whole US cents; `departsAt` is local time without an
/// offset.
///
/// A trip is booked by choosing seats. The server calls the id of a trip the
/// event ID, which is what an order sends.
abstract final class BusJson {
  /// `GET /catalog/bus/routes`: `{id, origin, destination, durationMinutes,
  /// operatorCount, tripCount, fromPriceCents}`.
  static BusRoute route(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      typicalDuration: Duration(minutes: (json['durationMinutes'] as num).toInt()),
      operatorCount: (json['operatorCount'] as num).toInt(),
      fromPriceCents: (json['fromPriceCents'] as num).toInt(),
    );
  }

  /// `GET /catalog/bus/departures`: `{id, routeId, operatorName, operatorCode,
  /// operatorColor, coachType, origin, destination, departsAt, durationMinutes,
  /// priceCents, amenities, seatsLeft, boardingPoint, boardingAddress, about}`.
  static BusDeparture departure(Map<String, dynamic> json) {
    return BusDeparture(
      id: json['id'] as String,
      routeId: json['routeId'] as String,
      operatorName: json['operatorName'] as String,
      operatorCode: json['operatorCode'] as String,
      operatorColor: (json['operatorColor'] as num).toInt(),
      coachType: json['coachType'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departsAt: DateTime.parse(json['departsAt'] as String),
      duration: Duration(minutes: (json['durationMinutes'] as num).toInt()),
      priceCents: (json['priceCents'] as num).toInt(),
      amenities: [for (final item in json['amenities'] as List<dynamic>) item as String],
      seatsLeft: (json['seatsLeft'] as num).toInt(),
      boardingPoint: json['boardingPoint'] as String,
      boardingAddress: json['boardingAddress'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// A trip as the event inside a booking describes it: the boarding point is
  /// the venue, the address its detail, and `bus` has the route, the coach and
  /// the company's badge. How many seats are left is not part of a booking.
  static BusDeparture departureOfBooking(Map<String, dynamic> event) {
    final bus = event['bus'] as Map<String, dynamic>;
    final tickets = event['ticketTypes'] as List<dynamic>;
    final origin = bus['origin'] as String;
    final destination = bus['destination'] as String;
    return BusDeparture(
      id: event['id'] as String,
      routeId: routeId(origin, destination),
      operatorName: event['organiser'] as String? ?? '',
      operatorCode: bus['operatorCode'] as String,
      operatorColor: (bus['operatorColor'] as num).toInt(),
      coachType: bus['coachLabel'] as String,
      origin: origin,
      destination: destination,
      departsAt: DateTime.parse(event['startsAt'] as String),
      duration: Duration(minutes: (bus['durationMinutes'] as num).toInt()),
      priceCents: tickets.isEmpty ? 0 : ((tickets.first as Map<String, dynamic>)['priceCents'] as num).toInt(),
      amenities: [for (final item in bus['amenities'] as List<dynamic>? ?? const []) item as String],
      seatsLeft: 0,
      boardingPoint: event['venue'] as String,
      boardingAddress: event['venueDetail'] as String? ?? '',
      imageUrl: event['imageUrl'] as String?,
    );
  }

  /// `GET /catalog/bus/departures/{id}/seats`: `{seatType, priceCents, rows}`,
  /// each row a list of `{id, label, detail, status}` with null for the aisle.
  /// A cinema hall's seats come the same way, with a screen in front.
  static SeatMap seatMap(Map<String, dynamic> json, {bool hasScreen = false}) {
    return SeatMap(
      seatType: json['seatType'] as String,
      priceCents: (json['priceCents'] as num).toInt(),
      hasScreen: hasScreen,
      rows: [
        for (final row in json['rows'] as List<dynamic>)
          [
            for (final seat in row as List<dynamic>)
              seat == null ? null : _seat(seat as Map<String, dynamic>),
          ],
      ],
    );
  }

  /// A seat booked on a trip, as `seats` of a booking names it (`3A`). Only its
  /// name is known.
  static Seat bookedSeat(String id) => Seat(id: id, label: id, detail: '');

  /// `phnom-penh-siem-reap`: the same name the server gives the route.
  static String routeId(String origin, String destination) {
    String slug(String place) =>
        place
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
    return '${slug(origin)}-${slug(destination)}';
  }

  static Seat _seat(Map<String, dynamic> json) {
    return Seat(
      id: json['id'] as String,
      label: json['label'] as String,
      detail: json['detail'] as String? ?? '',
      status: switch (json['status']) {
        'takenByFemale' => SeatStatus.takenByFemale,
        'takenByMale' => SeatStatus.takenByMale,
        'taken' => SeatStatus.taken,
        _ => SeatStatus.available,
      },
    );
  }
}
