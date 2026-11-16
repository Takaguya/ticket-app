import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/business_type.dart';
import '../../../domain/usecases/register_business.dart';

part 'register_business_event.dart';
part 'register_business_state.dart';

/// Step 2 of registration: the business details, entered after the phone
/// number has been confirmed.
class RegisterBusinessBloc extends Bloc<RegisterBusinessEvent, RegisterBusinessState> {
  RegisterBusinessBloc({required this._registerBusiness, required this._registrationToken})
    : super(const RegisterBusinessState()) {
    on<RegisterBusinessNameChanged>(
      (event, emit) => emit(state.copyWith(businessName: event.name)),
    );
    on<RegisterContactNameChanged>(
      (event, emit) => emit(state.copyWith(contactName: event.name)),
    );
    on<RegisterBusinessTypeChanged>(
      (event, emit) => emit(state.copyWith(type: event.type)),
    );
    on<RegisterBusinessSubmitted>(_onSubmitted);
  }

  final RegisterBusiness _registerBusiness;
  final String _registrationToken;

  Future<void> _onSubmitted(
    RegisterBusinessSubmitted event,
    Emitter<RegisterBusinessState> emit,
  ) async {
    if (state.isSubmitting) return;

    if (!state.isBusinessNameValid) {
      _emitFailure(emit, 'Enter your business name');
      return;
    }
    if (!state.isContactNameValid) {
      _emitFailure(emit, 'Enter your name');
      return;
    }

    emit(state.copyWith(status: RegisterBusinessStatus.submitting));
    final result = await _registerBusiness(
      RegisterBusinessParams(
        registrationToken: _registrationToken,
        businessName: state.businessName,
        contactName: state.contactName,
        type: state.type,
      ),
    );
    result.when(
      success: (_) => emit(state.copyWith(status: RegisterBusinessStatus.success)),
      failure: (failure) => _emitFailure(emit, failure.message),
    );
  }

  /// Reports the failure once, then returns to editing so the same message
  /// can be reported again on the next attempt.
  void _emitFailure(Emitter<RegisterBusinessState> emit, String message) {
    emit(state.copyWith(status: RegisterBusinessStatus.failure, errorMessage: message));
    emit(state.copyWith(status: RegisterBusinessStatus.editing));
  }
}
