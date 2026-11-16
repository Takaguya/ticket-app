import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/phone_number.dart';
import '../../../domain/entities/otp_verification.dart';
import '../../../domain/usecases/request_otp.dart';

part 'login_event.dart';
part 'login_state.dart';

/// The first sign-in screen: choose log in or register, type a phone number
/// and ask for a code.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required this._requestOtp}) : super(const LoginState()) {
    on<LoginModeChanged>(
      (event, emit) => emit(state.copyWith(mode: event.mode, status: LoginStatus.idle)),
    );
    on<LoginPhoneChanged>(
      (event, emit) => emit(state.copyWith(phone: event.phone, status: LoginStatus.idle)),
    );
    on<LoginSubmitted>(_onSubmitted);
  }

  final RequestOtp _requestOtp;

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    if (state.isSubmitting) return;

    if (!state.isPhoneValid) {
      _emitFailure(emit, 'Please enter a valid phone number');
      return;
    }

    emit(state.copyWith(status: LoginStatus.submitting));
    final result = await _requestOtp(
      RequestOtpParams(phone: state.e164Phone, purpose: state.mode),
    );
    result.when(
      success: (_) => emit(state.copyWith(status: LoginStatus.codeSent)),
      failure: (failure) => _emitFailure(emit, failure.message),
    );
  }

  /// Reports the failure once, then returns to idle so the same message can
  /// be reported again on the next attempt.
  void _emitFailure(Emitter<LoginState> emit, String message) {
    emit(state.copyWith(status: LoginStatus.failure, errorMessage: message));
    emit(state.copyWith(status: LoginStatus.idle));
  }
}
