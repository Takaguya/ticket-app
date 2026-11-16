part of 'seat_selection_bloc.dart';

sealed class SeatSelectionEvent extends Equatable {
  const SeatSelectionEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened, or "Try again" was tapped.
final class SeatSelectionStarted extends SeatSelectionEvent {
  const SeatSelectionStarted();
}

/// The person tapped a seat: chosen if free, let go if already chosen.
final class SeatToggled extends SeatSelectionEvent {
  const SeatToggled(this.seat);

  final Seat seat;

  @override
  List<Object?> get props => [seat];
}
