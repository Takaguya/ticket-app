import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/check_in_result.dart';
import '../../../domain/usecases/check_in_booking.dart';

// Events ---------------------------------------------------------------------

sealed class CheckInEvent extends Equatable {
  const CheckInEvent();

  @override
  List<Object?> get props => [];
}

/// A QR code was scanned, a booking ID was typed, or "Check in" was tapped.
final class CheckInRequested extends CheckInEvent {
  const CheckInRequested({required this.eventId, required this.code, this.fromCamera = false});

  final String eventId;
  final String code;

  /// Read by the camera rather than typed or tapped. The camera keeps
  /// seeing a QR code that is still held up, so repeats are ignored briefly.
  final bool fromCamera;

  @override
  List<Object?> get props => [eventId, code, fromCamera];
}

/// The result has been seen: ready for the next guest.
final class CheckInCleared extends CheckInEvent {
  const CheckInCleared();
}

// State ----------------------------------------------------------------------

enum CheckInStatus {
  idle,
  checking,

  /// The server answered: see [CheckInState.result].
  decided,

  /// The request itself failed: show [CheckInState.errorMessage].
  failure,
}

final class CheckInState extends Equatable {
  const CheckInState({this.status = CheckInStatus.idle, this.result, this.errorMessage});

  final CheckInStatus status;
  final CheckInResult? result;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, result, errorMessage];
}

// Bloc -----------------------------------------------------------------------

/// Checks one booking in at a time. Further scans are ignored until the
/// current result has been cleared, so a QR code held in front of the camera
/// is not submitted over and over.
class CheckInBloc extends Bloc<CheckInEvent, CheckInState> {
  CheckInBloc({required this._checkIn, this._clock = DateTime.now})
    : super(const CheckInState()) {
    on<CheckInRequested>(_onRequested);
    on<CheckInCleared>((event, emit) {
      _lastClearedAt = _clock();
      emit(const CheckInState());
    });
  }

  /// How long the camera ignores the code it has just answered, so a guest
  /// still holding up their phone is not scanned a second time.
  static const cameraRepeatWindow = Duration(seconds: 4);

  final CheckInBooking _checkIn;
  final DateTime Function() _clock;
  String? _lastCode;
  DateTime? _lastClearedAt;

  Future<void> _onRequested(CheckInRequested event, Emitter<CheckInState> emit) async {
    if (state.status != CheckInStatus.idle) return;

    final clearedAt = _lastClearedAt;
    final isRepeat =
        event.fromCamera &&
        event.code == _lastCode &&
        clearedAt != null &&
        _clock().difference(clearedAt) < cameraRepeatWindow;
    if (isRepeat) return;
    _lastCode = event.code;

    emit(const CheckInState(status: CheckInStatus.checking));
    final result = await _checkIn(CheckInParams(eventId: event.eventId, code: event.code));
    result.when(
      success: (decision) =>
          emit(CheckInState(status: CheckInStatus.decided, result: decision)),
      failure: (failure) {
        emit(CheckInState(status: CheckInStatus.failure, errorMessage: failure.message));
        emit(const CheckInState());
      },
    );
  }
}
