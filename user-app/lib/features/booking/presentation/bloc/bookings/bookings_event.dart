part of 'bookings_bloc.dart';

sealed class BookingsEvent extends Equatable {
  const BookingsEvent();

  @override
  List<Object?> get props => [];
}

/// The list opened, or "Try again" was tapped.
final class BookingsStarted extends BookingsEvent {
  const BookingsStarted();
}

/// A new answer from the repository.
final class _BookingsChanged extends BookingsEvent {
  const _BookingsChanged(this.result);

  final Result<List<Booking>> result;

  @override
  List<Object?> get props => [result];
}
