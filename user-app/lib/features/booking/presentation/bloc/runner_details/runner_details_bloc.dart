import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/phone_number.dart';
import '../../../../auth/domain/entities/gender.dart';
import '../../../../auth/domain/entities/pin_user.dart';
import '../../../domain/entities/runner_details.dart';
import '../../../domain/usecases/get_saved_runner.dart';

part 'runner_details_event.dart';
part 'runner_details_state.dart';

/// The runner's details for a race. For the signed-in person the form starts
/// from their account and from details saved at an earlier race; for
/// someone else it starts empty, with the person as the emergency contact.
class RunnerDetailsBloc extends Bloc<RunnerDetailsEvent, RunnerDetailsState> {
  RunnerDetailsBloc({
    required this._getSavedRunner,
    required this._clock,
    required this.account,
  }) : super(const RunnerDetailsState()) {
    on<RunnerDetailsStarted>(_onStarted);
    on<RunnerForSomeoneElseChanged>(_onForSomeoneElseChanged);
    on<RunnerTextChanged>(_onTextChanged);
    on<RunnerGenderChosen>((event, emit) => emit(state.copyWith(gender: event.gender)));
    on<RunnerShirtSizeChosen>((event, emit) => emit(state.copyWith(shirtSize: event.size)));
    on<RunnerSaveChanged>((event, emit) => emit(state.copyWith(saveToAccount: event.save)));
  }

  final GetSavedRunner _getSavedRunner;
  final Clock _clock;

  /// The signed-in person.
  final PinUser account;

  RunnerDetails? _saved;

  Future<void> _onStarted(RunnerDetailsStarted event, Emitter<RunnerDetailsState> emit) async {
    final result = await _getSavedRunner(const NoParams());
    // Without the saved details the form still starts from the account.
    _saved = switch (result) {
      Success(:final value) => value,
      FailureResult() => null,
    };
    emit(_filledForMe());
  }

  void _onForSomeoneElseChanged(
    RunnerForSomeoneElseChanged event,
    Emitter<RunnerDetailsState> emit,
  ) {
    if (event.forSomeoneElse == state.forSomeoneElse) return;
    emit(
      event.forSomeoneElse
          ? RunnerDetailsState(
              status: RunnerDetailsStatus.ready,
              forSomeoneElse: true,
              emergencyName: account.name,
              emergencyPhone: PhoneNumber.formatNational(account.phone),
              saveToAccount: false,
              formVersion: state.formVersion + 1,
            )
          : _filledForMe(),
    );
  }

  void _onTextChanged(RunnerTextChanged event, Emitter<RunnerDetailsState> emit) {
    final value = event.value;
    emit(switch (event.field) {
      RunnerField.name => state.copyWith(name: value),
      RunnerField.phone => state.copyWith(phone: value),
      RunnerField.email => state.copyWith(email: value),
      RunnerField.age => state.copyWith(age: value),
      RunnerField.nationality => state.copyWith(nationality: value),
      RunnerField.emergencyName => state.copyWith(emergencyName: value),
      RunnerField.emergencyPhone => state.copyWith(emergencyPhone: value),
    });
  }

  /// The signed-in person's own details. The age always comes from the date
  /// of birth, so it is right in later years too.
  RunnerDetailsState _filledForMe() {
    final saved = _saved;
    final age = _ageOn(account.dateOfBirth, _clock.now());
    return RunnerDetailsState(
      status: RunnerDetailsStatus.ready,
      name: account.name,
      phone: PhoneNumber.formatNational(account.phone),
      email: saved?.email ?? account.email ?? '',
      gender: saved?.gender ?? account.gender,
      age: age >= RunnerDetails.minAge && age <= RunnerDetails.maxAge ? '$age' : '',
      nationality: saved?.nationality ?? '',
      shirtSize: saved?.shirtSize,
      emergencyName: saved?.emergencyName ?? '',
      emergencyPhone: saved == null ? '' : PhoneNumber.formatNational(saved.emergencyPhone),
      filledFromSaved: saved != null,
      formVersion: state.formVersion + 1,
    );
  }

  static int _ageOn(DateTime birth, DateTime now) {
    final hadBirthday =
        now.month > birth.month || (now.month == birth.month && now.day >= birth.day);
    return now.year - birth.year - (hadBirthday ? 0 : 1);
  }
}
