import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/booking_request.dart';
import '../../../domain/entities/snack.dart';
import '../../../domain/usecases/get_snacks.dart';

part 'snacks_event.dart';
part 'snacks_state.dart';

/// Snacks to add to cinema seats, picked up at the counter with the ticket.
class SnacksBloc extends Bloc<SnacksEvent, SnacksState> {
  SnacksBloc({required this._getSnacks, required CinemaRequest request})
    : super(SnacksState(request: request)) {
    on<SnacksStarted>(_onStarted);
    on<SnackAdded>(_onAdded);
    on<SnackRemoved>(_onRemoved);
  }

  /// Most of one snack in one booking.
  static const maxEach = 10;

  final GetSnacks _getSnacks;

  Future<void> _onStarted(SnacksStarted event, Emitter<SnacksState> emit) async {
    emit(state.copyWith(status: SnacksStatus.loading));
    final result = await _getSnacks(state.request.theatre.id);
    emit(
      result.when(
        success: (snacks) => state.copyWith(status: SnacksStatus.ready, snacks: snacks),
        failure: (failure) =>
            state.copyWith(status: SnacksStatus.failure, errorMessage: failure.message),
      ),
    );
  }

  void _onAdded(SnackAdded event, Emitter<SnacksState> emit) {
    final quantity = state.quantityOf(event.snack);
    if (quantity >= maxEach) {
      emit(state.copyWith(notice: () => 'Maximum $maxEach of each snack'));
      emit(state.copyWith(notice: () => null));
      return;
    }
    emit(state.copyWith(quantities: {...state.quantities, event.snack: quantity + 1}));
  }

  void _onRemoved(SnackRemoved event, Emitter<SnacksState> emit) {
    final quantity = state.quantityOf(event.snack);
    if (quantity == 0) return;
    emit(state.copyWith(quantities: {...state.quantities, event.snack: quantity - 1}));
  }
}
