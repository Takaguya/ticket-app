import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/booking.dart';
import '../../../domain/usecases/cancel_booking.dart';

// Events ---------------------------------------------------------------------

sealed class CancelBookingEvent extends Equatable {
  const CancelBookingEvent();

  @override
  List<Object?> get props => [];
}

/// A reason was picked in the cancel sheet.
final class CancelReasonChosen extends CancelBookingEvent {
  const CancelReasonChosen(this.reason);

  final CancelReason reason;

  @override
  List<Object?> get props => [reason];
}

/// The cancel sheet was opened: an error from an earlier try is dropped.
final class CancelSheetOpened extends CancelBookingEvent {
  const CancelSheetOpened();
}

/// "Cancel booking" was confirmed in the sheet.
final class CancelConfirmed extends CancelBookingEvent {
  const CancelConfirmed();
}

// State ----------------------------------------------------------------------

final class CancelBookingState extends Equatable {
  const CancelBookingState({
    this.reason,
    this.submitting = false,
    this.cancelled = false,
    this.errorMessage,
  });

  /// The reason picked so far. One must be chosen before confirming.
  final CancelReason? reason;
  final bool submitting;

  /// The server cancelled the booking: the sheet can close.
  final bool cancelled;

  /// Why the last try failed, shown in the sheet.
  final String? errorMessage;

  @override
  List<Object?> get props => [reason, submitting, cancelled, errorMessage];
}

// Bloc -----------------------------------------------------------------------

/// Cancels one booking: the owner picks a reason, then confirms. The bookings
/// list updates by itself, so the detail page shows the cancellation at once.
class CancelBookingBloc extends Bloc<CancelBookingEvent, CancelBookingState> {
  CancelBookingBloc({required this._cancelBooking, required this.bookingId})
    : super(const CancelBookingState()) {
    on<CancelReasonChosen>((event, emit) {
      // A request in flight keeps its reason and its spinner.
      if (_isBusyOrDone) return;
      emit(CancelBookingState(reason: event.reason));
    });
    on<CancelSheetOpened>((event, emit) {
      if (_isBusyOrDone || state.errorMessage == null) return;
      emit(CancelBookingState(reason: state.reason));
    });
    on<CancelConfirmed>(_onConfirmed);
  }

  bool get _isBusyOrDone => state.submitting || state.cancelled;

  final CancelBooking _cancelBooking;
  final String bookingId;

  Future<void> _onConfirmed(CancelConfirmed event, Emitter<CancelBookingState> emit) async {
    final reason = state.reason;
    if (state.submitting || state.cancelled) return;
    if (reason == null) {
      emit(const CancelBookingState(errorMessage: 'Choose why you are cancelling.'));
      return;
    }

    emit(CancelBookingState(reason: reason, submitting: true));
    final result = await _cancelBooking(CancelBookingParams(bookingId: bookingId, reason: reason));
    result.when(
      success: (_) => emit(CancelBookingState(reason: reason, cancelled: true)),
      failure: (failure) => emit(CancelBookingState(reason: reason, errorMessage: failure.message)),
    );
  }
}
