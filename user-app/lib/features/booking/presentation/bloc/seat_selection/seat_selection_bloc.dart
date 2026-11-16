import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/result/result.dart';
import '../../../domain/entities/booking_request.dart';
import '../../../domain/entities/seat_map.dart';
import '../../../domain/usecases/get_seat_map.dart';

part 'seat_selection_event.dart';
part 'seat_selection_state.dart';

/// Choosing seats on a bus or at a screening, up to
/// [SeatMap.maxSeatsPerBooking].
class SeatSelectionBloc extends Bloc<SeatSelectionEvent, SeatSelectionState> {
  SeatSelectionBloc({required this._getSeatMap, required BookingRequest request})
    : assert(request is BusRequest || request is CinemaRequest, 'Only buses and screenings have seats'),
      super(SeatSelectionState(request: request)) {
    on<SeatSelectionStarted>(_onStarted);
    on<SeatToggled>(_onToggled);
  }

  final GetSeatMap _getSeatMap;

  Future<void> _onStarted(SeatSelectionStarted event, Emitter<SeatSelectionState> emit) async {
    emit(state.copyWith(status: SeatSelectionStatus.loading));
    final SeatsOf of = switch (state.request) {
      BusRequest(:final departure) => SeatsOfBus(departure),
      CinemaRequest(:final showtime) => SeatsOfShowtime(showtime),
      EventRequest() || AdmissionRequest() => throw StateError('Only buses and screenings have seats'),
    };
    switch (await _getSeatMap(of)) {
      case Success(value: final seatMap):
        // Seats chosen before a reload stay chosen while they are still free.
        final stillFree = [
          for (final seat in state.selected)
            if (seatMap.seat(seat.id) case final current? when !current.status.isTaken) current,
        ];
        emit(
          state.copyWith(status: SeatSelectionStatus.ready, seatMap: seatMap, selected: stillFree),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(status: SeatSelectionStatus.failure, errorMessage: failure.message));
    }
  }

  void _onToggled(SeatToggled event, Emitter<SeatSelectionState> emit) {
    final seat = event.seat;
    if (seat.status.isTaken) return;
    if (state.isSelected(seat)) {
      emit(state.copyWith(selected: state.selected.where((chosen) => chosen.id != seat.id).toList()));
      return;
    }
    if (state.selected.length >= SeatMap.maxSeatsPerBooking) {
      _notify(emit, 'Maximum ${SeatMap.maxSeatsPerBooking} seats per booking');
      return;
    }
    emit(state.copyWith(selected: [...state.selected, seat]));
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<SeatSelectionState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
