import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/result/result.dart';
import '../../../../../core/utils/clock.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/usecases/watch_bookings.dart';

part 'bookings_event.dart';
part 'bookings_state.dart';

/// The person's bookings, upcoming and past. Follows the repository, so a
/// booking made elsewhere in the app shows up here by itself.
class BookingsBloc extends Bloc<BookingsEvent, BookingsState> {
  BookingsBloc({required this._watchBookings, required this._clock})
    : super(const BookingsState()) {
    on<BookingsStarted>(_onStarted);
    on<_BookingsChanged>(_onChanged);
  }

  final WatchBookings _watchBookings;
  final Clock _clock;
  StreamSubscription<Result<List<Booking>>>? _subscription;

  Future<void> _onStarted(BookingsStarted event, Emitter<BookingsState> emit) async {
    emit(state.copyWith(status: BookingsStatus.loading));
    await _subscription?.cancel();
    _subscription = _watchBookings().listen((result) => add(_BookingsChanged(result)));
  }

  void _onChanged(_BookingsChanged event, Emitter<BookingsState> emit) {
    switch (event.result) {
      case Success(value: final bookings):
        emit(BookingsState(status: BookingsStatus.loaded, bookings: bookings, now: _clock.now()));
      case FailureResult(:final failure):
        // A failed refresh keeps the list already shown.
        if (state.status != BookingsStatus.loaded) {
          emit(state.copyWith(status: BookingsStatus.failure, errorMessage: failure.message));
        }
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
