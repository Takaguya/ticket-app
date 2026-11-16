import 'package:equatable/equatable.dart';

/// A cinema, e.g. "Legend Cinema · Aeon Mall 1".
class Theatre extends Equatable {
  const Theatre({required this.id, required this.name, required this.area});

  final String id;
  final String name;

  /// Where it is, e.g. "Sen Sok · 3.2 km".
  final String area;

  @override
  List<Object?> get props => [id, name, area];
}

/// One screening of a film.
class Showtime extends Equatable {
  const Showtime({
    required this.id,
    required this.startsAt,
    required this.hall,
    required this.priceCents,
  });

  final String id;
  final DateTime startsAt;

  /// e.g. "Hall 2" or "IMAX".
  final String hall;

  /// Per seat, in whole US cents.
  final int priceCents;

  @override
  List<Object?> get props => [id, startsAt, hall, priceCents];
}

/// A cinema and the times it shows a film on one day.
class TheatreShowtimes extends Equatable {
  const TheatreShowtimes({required this.theatre, required this.showtimes});

  final Theatre theatre;
  final List<Showtime> showtimes;

  @override
  List<Object?> get props => [theatre, showtimes];
}
