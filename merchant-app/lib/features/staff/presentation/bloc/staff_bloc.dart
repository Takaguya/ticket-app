import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/team.dart';
import '../../domain/usecases/regenerate_join_code.dart';
import '../../domain/usecases/remove_staff_member.dart';
import '../../domain/usecases/watch_team.dart';

// Events ---------------------------------------------------------------------

sealed class StaffEvent extends Equatable {
  const StaffEvent();

  @override
  List<Object?> get props => [];
}

/// The Staff screen opened: start following the team.
final class StaffStarted extends StaffEvent {
  const StaffStarted();
}

final class StaffMemberRemoved extends StaffEvent {
  const StaffMemberRemoved(this.member);

  final StaffMember member;

  @override
  List<Object?> get props => [member];
}

final class StaffJoinCodeRenewed extends StaffEvent {
  const StaffJoinCodeRenewed();
}

// State ----------------------------------------------------------------------

enum StaffStatus { loading, ready, failure }

final class StaffState extends Equatable {
  const StaffState({this.status = StaffStatus.loading, this.team, this.notice});

  final StaffStatus status;

  /// Set when [status] is [StaffStatus.ready].
  final Team? team;

  /// One-off message for a toast.
  final String? notice;

  StaffState copyWith({StaffStatus? status, Team? team, String? Function()? notice}) {
    return StaffState(
      status: status ?? this.status,
      team: team ?? this.team,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [status, team, notice];
}

// Bloc -----------------------------------------------------------------------

/// The owner's Staff screen: the team list, removing scanners and renewing
/// the join code.
class StaffBloc extends Bloc<StaffEvent, StaffState> {
  StaffBloc({
    required this._watchTeam,
    required this._removeMember,
    required this._regenerateJoinCode,
  }) : super(const StaffState()) {
    on<StaffStarted>(_onStarted);
    on<StaffMemberRemoved>(_onMemberRemoved);
    on<StaffJoinCodeRenewed>(_onJoinCodeRenewed);
  }

  final WatchTeam _watchTeam;
  final RemoveStaffMember _removeMember;
  final RegenerateJoinCode _regenerateJoinCode;

  Future<void> _onStarted(StaffStarted event, Emitter<StaffState> emit) {
    return emit.forEach(
      _watchTeam(),
      onData: (team) => state.copyWith(status: StaffStatus.ready, team: team),
      onError: (_, _) => state.copyWith(status: StaffStatus.failure),
    );
  }

  Future<void> _onMemberRemoved(StaffMemberRemoved event, Emitter<StaffState> emit) async {
    final result = await _removeMember(event.member.id);
    _notify(
      emit,
      result.when(
        success: (_) => '${event.member.name} removed',
        failure: (failure) => failure.message,
      ),
    );
  }

  Future<void> _onJoinCodeRenewed(StaffJoinCodeRenewed event, Emitter<StaffState> emit) async {
    final result = await _regenerateJoinCode(const NoParams());
    _notify(
      emit,
      result.when(
        success: (_) => 'New code created. The old one no longer works.',
        failure: (failure) => failure.message,
      ),
    );
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<StaffState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
