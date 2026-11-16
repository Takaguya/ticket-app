part of 'ticket_bloc.dart';

sealed class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened, or "Try again" was tapped.
final class TicketStarted extends TicketEvent {
  const TicketStarted();
}
