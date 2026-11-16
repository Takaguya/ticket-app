import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/gender.dart';
import '../../../domain/usecases/register_account.dart';

part 'register_event.dart';
part 'register_state.dart';

/// "Your details", after a new phone number is confirmed: name, gender, date
/// of birth and, optionally, email. Creates the account and signs in.
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({required this._registerAccount, required this._registrationToken})
    : super(const RegisterState()) {
    on<RegisterNameChanged>((event, emit) => emit(state.copyWith(name: event.name)));
    on<RegisterGenderChanged>((event, emit) => emit(state.copyWith(gender: event.gender)));
    on<RegisterDateOfBirthChanged>(
      (event, emit) => emit(state.copyWith(dateOfBirth: event.dateOfBirth)),
    );
    on<RegisterEmailChanged>((event, emit) => emit(state.copyWith(email: event.email)));
    on<RegisterSubmitted>(_onSubmitted);
  }

  final RegisterAccount _registerAccount;
  final String _registrationToken;

  Future<void> _onSubmitted(RegisterSubmitted event, Emitter<RegisterState> emit) async {
    if (state.status == RegisterStatus.submitting) return;

    final problem = state.firstProblem;
    if (problem != null) {
      _emitFailure(emit, problem);
      return;
    }

    emit(state.copyWith(status: RegisterStatus.submitting));
    final email = state.email.trim();
    final result = await _registerAccount(
      RegisterAccountParams(
        registrationToken: _registrationToken,
        name: state.name.trim(),
        gender: state.gender!,
        dateOfBirth: state.dateOfBirth!,
        email: email.isEmpty ? null : email,
      ),
    );
    result.when(
      // The router sees the new session and opens the app.
      success: (_) => emit(state.copyWith(status: RegisterStatus.registered)),
      failure: (failure) => _emitFailure(emit, failure.message),
    );
  }

  /// Reports the failure once, then returns to idle so the same message can
  /// be reported again on the next attempt.
  void _emitFailure(Emitter<RegisterState> emit, String message) {
    emit(state.copyWith(status: RegisterStatus.failure, errorMessage: message));
    emit(state.copyWith(status: RegisterStatus.idle));
  }
}
