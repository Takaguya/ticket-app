import '../../../core/utils/date_format.dart';
import '../domain/entities/booking_request.dart';
import '../domain/entities/seat_map.dart';

/// How the booking pages put what is booked into words.
extension BookingRequestText on BookingRequest {
  /// "Sun 22 Nov 2026 · 19:00"; for a place "Sun 22 Nov 2026 · Valid all day".
  String get whenText => this is AdmissionRequest
      ? '${DateFormat.long(startsAt)} · Valid all day'
      : '${DateFormat.long(startsAt)} · ${DateFormat.time(startsAt)}';

  /// "19:00", or "All day" for a place.
  String get timeText => this is AdmissionRequest ? 'All day' : DateFormat.time(startsAt);

  /// "1 ticket", "3 tickets".
  String get ticketCountText => ticketCount == 1 ? '1 ticket' : '$ticketCount tickets';

  /// The seats chosen on a bus or at a film; none otherwise.
  List<Seat> get seats => switch (this) {
    BusRequest(:final seats) || CinemaRequest(:final seats) => seats,
    EventRequest() || AdmissionRequest() => const [],
  };

  /// What the tickets are: "1× General admission, 2× VIP", or the seats:
  /// "Seats F5, F6".
  String get ticketsText => lines
      .where((line) => line.isTicket)
      .map((line) => seats.isEmpty ? '${line.quantity}× ${line.name}' : line.name)
      .join(', ');
}
