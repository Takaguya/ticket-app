import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/booking.dart';
import '../../../domain/usecases/get_booking.dart';

part 'ticket_event.dart';
part 'ticket_state.dart';

/// One booking, shown as its ticket. Starts with [initial] when the page
/// that opened it already had the booking, e.g. right after paying.
class TicketBloc extends Bloc<TicketEvent, TicketState> {
  TicketBloc({required this._getBooking, required this.bookingId, Booking? initial})
    : super(
        initial == null
            ? const TicketState()
            : TicketState(status: TicketStatus.loaded, booking: initial),
      ) {
    on<TicketStarted>(_onStarted);
  }

  final GetBooking _getBooking;
  final String bookingId;

  Future<void> _onStarted(TicketStarted event, Emitter<TicketState> emit) async {
    if (state.status == TicketStatus.loaded) return;
    emit(const TicketState());
    final result = await _getBooking(bookingId);
    emit(
      result.when(
        success: (booking) => TicketState(status: TicketStatus.loaded, booking: booking),
        failure: (failure) =>
            TicketState(status: TicketStatus.failure, errorMessage: failure.message),
      ),
    );
  }
}
