import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/ticker.dart';
import '../../../domain/entities/otp_verification.dart';
import '../../../domain/usecases/request_otp.dart';
import '../../../domain/usecases/verify_otp.dart';

part 'otp_event.dart';
part 'otp_state.dart';

/// The code screen: collects the 6 digits, verifies them as soon as they are
/// complete, and lets the person ask for a new code after a short wait.
class OtpBloc extends Bloc<OtpEvent, OtpState> {
  OtpBloc({
    required this._verifyOtp,
    required this._requestOtp,
    required this._ticker,
    required String phone,
    required OtpPurpose purpose,
  }) : super(OtpState(phone: phone, purpose: purpose)) {
    on<OtpStarted>((event, emit) => _startCountdown(emit));
    on<OtpCodeChanged>(_onCodeChanged);
    on<OtpSubmitted>(_onSubmitted);
    on<OtpResendRequested>(_onResendRequested);
    on<_OtpTicked>((event, emit) => emit(state.copyWith(secondsLeft: event.secondsLeft)));
  }

  /// How long the person waits before they can ask for another code.
  static const resendDelaySeconds = 30;

  final VerifyOtp _verifyOtp;
  final RequestOtp _requestOtp;
  final Ticker _ticker;
  StreamSubscription<int>? _tickerSubscription;

  Future<void> _onCodeChanged(OtpCodeChanged event, Emitter<OtpState> emit) async {
    if (state.isBusy) return;

    final digits = event.code.replaceAll(RegExp(r'\D'), '');
    final code = digits.substring(0, math.min(digits.length, OtpState.codeLength));
    emit(state.copyWith(code: code, errorMessage: () => null));

    if (state.isCodeComplete) await _verify(emit);
  }

  Future<void> _onSubmitted(OtpSubmitted event, Emitter<OtpState> emit) async {
    if (state.isBusy) return;

    if (!state.isCodeComplete) {
      emit(state.copyWith(errorMessage: () => 'Enter all 6 digits'));
      return;
    }
    await _verify(emit);
  }

  Future<void> _verify(Emitter<OtpState> emit) async {
    emit(state.copyWith(status: OtpStatus.verifying));
    final result = await _verifyOtp(
      VerifyOtpParams(phone: state.phone, code: state.code, purpose: state.purpose),
    );
    result.when(
      success: (verification) {
        _tickerSubscription?.cancel();
        emit(state.copyWith(status: OtpStatus.verified, verification: verification));
      },
      failure: (failure) => emit(
        state.copyWith(
          status: OtpStatus.editing,
          // A wrong code is cleared so the person can type again; after a
          // connection problem the digits stay for a retry.
          code: failure is InvalidCodeFailure ? '' : state.code,
          errorMessage: () => failure.message,
        ),
      ),
    );
  }

  Future<void> _onResendRequested(OtpResendRequested event, Emitter<OtpState> emit) async {
    if (!state.canResend) return;

    emit(state.copyWith(status: OtpStatus.resending));
    final result = await _requestOtp(
      RequestOtpParams(phone: state.phone, purpose: state.purpose),
    );
    result.when(
      success: (_) {
        emit(state.copyWith(status: OtpStatus.editing, code: '', errorMessage: () => null));
        _startCountdown(emit);
        _notify(emit, 'A new code is on its way');
      },
      failure: (failure) {
        emit(state.copyWith(status: OtpStatus.editing));
        _notify(emit, failure.message);
      },
    );
  }

  void _startCountdown(Emitter<OtpState> emit) {
    _tickerSubscription?.cancel();
    emit(state.copyWith(secondsLeft: resendDelaySeconds));
    _tickerSubscription = _ticker
        .countdown(from: resendDelaySeconds)
        .listen((secondsLeft) => add(_OtpTicked(secondsLeft)));
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<OtpState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }

  @override
  Future<void> close() async {
    await _tickerSubscription?.cancel();
    return super.close();
  }
}
