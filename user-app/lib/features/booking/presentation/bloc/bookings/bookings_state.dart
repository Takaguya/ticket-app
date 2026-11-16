part of 'bookings_bloc.dart';

enum BookingsStatus { loading, loaded, failure }

final class BookingsState extends Equatable {
  const BookingsState({
    this.status = BookingsStatus.loading,
    this.bookings = const [],
    this.now,
    this.errorMessage,
  });

  final BookingsStatus status;

  /// Soonest first.
  final List<Booking> bookings;

  /// When [bookings] arrived; what counts as past is measured from it.
  final DateTime? now;

  /// Why the bookings could not be loaded.
  final String? errorMessage;

  /// Today's and later bookings, soonest first.
  List<Booking> get upcoming => [
    for (final booking in bookings)
      if (now == null || !booking.isPastAt(now!)) booking,
  ];

  /// Earlier bookings, the most recent first.
  List<Booking> get past => [
    for (final booking in bookings.reversed)
      if (now != null && booking.isPastAt(now!)) booking,
  ];

  BookingsState copyWith({BookingsStatus? status, String? errorMessage}) {
    return BookingsState(
      status: status ?? this.status,
      bookings: bookings,
      now: now,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, bookings, now, errorMessage];
}
