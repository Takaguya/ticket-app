part of 'bus_search_bloc.dart';

sealed class BusSearchEvent extends Equatable {
  const BusSearchEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened, or "Try again" was tapped.
final class BusSearchStarted extends BusSearchEvent {
  const BusSearchStarted();
}

final class BusOriginChosen extends BusSearchEvent {
  const BusOriginChosen(this.place);

  final String place;

  @override
  List<Object?> get props => [place];
}

final class BusDestinationChosen extends BusSearchEvent {
  const BusDestinationChosen(this.place);

  final String place;

  @override
  List<Object?> get props => [place];
}

/// The person tapped the swap button between "From" and "To".
final class BusDirectionSwapped extends BusSearchEvent {
  const BusDirectionSwapped();
}

final class BusDateChosen extends BusSearchEvent {
  const BusDateChosen(this.date);

  final DateTime date;

  @override
  List<Object?> get props => [date];
}
