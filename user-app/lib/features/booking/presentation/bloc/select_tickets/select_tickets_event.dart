part of 'select_tickets_bloc.dart';

sealed class SelectTicketsEvent extends Equatable {
  const SelectTicketsEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened: a place asks what is left of today's tickets.
final class SelectTicketsStarted extends SelectTicketsEvent {
  const SelectTicketsStarted();
}

/// "+" next to a kind of ticket.
final class SelectTicketsAdded extends SelectTicketsEvent {
  const SelectTicketsAdded(this.tier);

  final TicketTier tier;

  @override
  List<Object?> get props => [tier];
}

/// "–" next to a kind of ticket.
final class SelectTicketsRemoved extends SelectTicketsEvent {
  const SelectTicketsRemoved(this.tier);

  final TicketTier tier;

  @override
  List<Object?> get props => [tier];
}

/// A place: the person tapped a day.
final class SelectTicketsDayChosen extends SelectTicketsEvent {
  const SelectTicketsDayChosen(this.day);

  final DateTime day;

  @override
  List<Object?> get props => [day];
}
