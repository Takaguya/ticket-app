import 'package:equatable/equatable.dart';

enum SeatStatus {
  available,
  taken,

  /// On buses a taken seat shows whether a woman or a man sits there, so
  /// people travelling alone can choose whom they sit next to.
  takenByFemale,
  takenByMale;

  bool get isTaken => this != available;
}

/// One seat: "3A" on a bus, "F5" in a cinema.
class Seat extends Equatable {
  const Seat({
    required this.id,
    required this.label,
    required this.detail,
    this.status = SeatStatus.available,
  });

  /// Unique on its map and printed on the ticket, e.g. "3A" or "F5".
  final String id;

  /// What the seat shows on the map: "3A" on a bus, just "5" in a cinema
  /// row.
  final String label;

  /// Where it is, e.g. "Row 3 · Window" or "Row F".
  final String detail;
  final SeatStatus status;

  @override
  List<Object?> get props => [id, label, detail, status];
}

/// The seats of one bus departure or one screening, front row first. A null
/// in a row is the aisle.
class SeatMap extends Equatable {
  const SeatMap({
    required this.rows,
    required this.seatType,
    required this.priceCents,
    this.hasScreen = false,
  });

  /// Most seats one booking can hold.
  static const maxSeatsPerBooking = 8;

  final List<List<Seat?>> rows;

  /// e.g. "Seater · standard · 2+2", or a cinema's hall.
  final String seatType;

  /// Per seat, in whole US cents.
  final int priceCents;

  /// A cinema: the screen is in front of the first row.
  final bool hasScreen;

  Seat? seat(String id) {
    for (final row in rows) {
      for (final seat in row) {
        if (seat?.id == id) return seat;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [rows, seatType, priceCents, hasScreen];
}
