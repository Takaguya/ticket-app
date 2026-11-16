part of 'ticket_bloc.dart';

enum TicketStatus { loading, loaded, failure }

final class TicketState extends Equatable {
  const TicketState({this.status = TicketStatus.loading, this.booking, this.errorMessage});

  final TicketStatus status;

  /// Set once loaded.
  final Booking? booking;

  /// Why the booking could not be loaded.
  final String? errorMessage;

  @override
  List<Object?> get props => [status, booking, errorMessage];
}
