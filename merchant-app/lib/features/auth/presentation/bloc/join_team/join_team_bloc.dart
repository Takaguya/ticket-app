import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/join_team.dart';

// Events ---------------------------------------------------------------------

sealed class JoinTeamEvent extends Equatable {
  const JoinTeamEvent();

  @override
  List<Object?> get props => [];
}

final class JoinTeamNameChanged extends JoinTeamEvent {
  const JoinTeamNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class JoinTeamCodeChanged extends JoinTeamEvent {
  const JoinTeamCodeChanged(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// The person tapped "Join team".
final class JoinTeamSubmitted extends JoinTeamEvent {
  const JoinTeamSubmitted();
}

// State ----------------------------------------------------------------------

enum JoinTeamStatus {
  editing,
  submitting,

  /// Joined and signed in as a scanner.
  success,

  /// Show [JoinTeamState.errorMessage].
  failure,
}

final class JoinTeamState extends Equatable {
  const JoinTeamState({
    this.name = '',
    this.code = '',
    this.status = JoinTeamStatus.editing,
    this.errorMessage,
  });

  static const codeLength = 6;

  final String name;

  /// As typed; spaces are ignored.
  final String code;
  final JoinTeamStatus status;
  final String? errorMessage;

  String get codeDigits => code.replaceAll(RegExp(r'\D'), '');
  bool get isNameValid => name.trim().length >= 2;
  bool get isCodeValid => codeDigits.length == codeLength;
  bool get isValid => isNameValid && isCodeValid;
  bool get isSubmitting => status == JoinTeamStatus.submitting;

  JoinTeamState copyWith({
    String? name,
    String? code,
    JoinTeamStatus? status,
    String? errorMessage,
  }) {
    return JoinTeamState(
      name: name ?? this.name,
      code: code ?? this.code,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [name, code, status, errorMessage];
}

// Bloc -----------------------------------------------------------------------

/// Joining a business as a scanner with the owner's join code.
class JoinTeamBloc extends Bloc<JoinTeamEvent, JoinTeamState> {
  JoinTeamBloc({required this._joinTeam, required this._registrationToken})
    : super(const JoinTeamState()) {
    on<JoinTeamNameChanged>((event, emit) => emit(state.copyWith(name: event.name)));
    on<JoinTeamCodeChanged>((event, emit) => emit(state.copyWith(code: event.code)));
    on<JoinTeamSubmitted>(_onSubmitted);
  }

  final JoinTeam _joinTeam;
  final String _registrationToken;

  Future<void> _onSubmitted(JoinTeamSubmitted event, Emitter<JoinTeamState> emit) async {
    if (state.isSubmitting) return;
    if (!state.isNameValid) return _emitFailure(emit, 'Enter your name');
    if (!state.isCodeValid) return _emitFailure(emit, 'Enter the 6-digit join code');

    emit(state.copyWith(status: JoinTeamStatus.submitting));
    final result = await _joinTeam(
      JoinTeamParams(
        registrationToken: _registrationToken,
        name: state.name,
        joinCode: state.codeDigits,
      ),
    );
    result.when(
      success: (_) => emit(state.copyWith(status: JoinTeamStatus.success)),
      failure: (failure) => _emitFailure(emit, failure.message),
    );
  }

  /// Reports the failure once, then returns to editing so the same message
  /// can be reported again on the next attempt.
  void _emitFailure(Emitter<JoinTeamState> emit, String message) {
    emit(state.copyWith(status: JoinTeamStatus.failure, errorMessage: message));
    emit(state.copyWith(status: JoinTeamStatus.editing));
  }
}
