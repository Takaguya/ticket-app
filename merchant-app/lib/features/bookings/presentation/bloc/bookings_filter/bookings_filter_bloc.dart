import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/booking_filter.dart';

// Events ---------------------------------------------------------------------

sealed class BookingsFilterEvent extends Equatable {
  const BookingsFilterEvent();

  @override
  List<Object?> get props => [];
}

/// Show the bookings of another event. Resets the search and status filter.
final class BookingsEventSelected extends BookingsFilterEvent {
  const BookingsEventSelected(this.eventId);

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

final class BookingsQueryChanged extends BookingsFilterEvent {
  const BookingsQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class BookingsStatusFilterChanged extends BookingsFilterEvent {
  const BookingsStatusFilterChanged(this.filter);

  final BookingFilter filter;

  @override
  List<Object?> get props => [filter];
}

// State ----------------------------------------------------------------------

final class BookingsFilterState extends Equatable {
  const BookingsFilterState({this.eventId, this.query = '', this.filter = BookingFilter.all});

  /// The chosen event, or null to show today's event (or the next one).
  final String? eventId;
  final String query;
  final BookingFilter filter;

  @override
  List<Object?> get props => [eventId, query, filter];
}

// Bloc -----------------------------------------------------------------------

/// What the Bookings screen is showing: which event, the search text and the
/// status filter. Lives above the tabs so other screens can open Bookings on
/// a particular event.
class BookingsFilterBloc extends Bloc<BookingsFilterEvent, BookingsFilterState> {
  BookingsFilterBloc() : super(const BookingsFilterState()) {
    on<BookingsEventSelected>(
      (event, emit) => emit(BookingsFilterState(eventId: event.eventId)),
    );
    on<BookingsQueryChanged>(
      (event, emit) => emit(
        BookingsFilterState(eventId: state.eventId, query: event.query, filter: state.filter),
      ),
    );
    on<BookingsStatusFilterChanged>(
      (event, emit) => emit(
        BookingsFilterState(eventId: state.eventId, query: state.query, filter: event.filter),
      ),
    );
  }
}
