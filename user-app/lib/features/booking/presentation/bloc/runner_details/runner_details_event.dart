part of 'runner_details_bloc.dart';

sealed class RunnerDetailsEvent extends Equatable {
  const RunnerDetailsEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened: fill the form from the account and saved details.
final class RunnerDetailsStarted extends RunnerDetailsEvent {
  const RunnerDetailsStarted();
}

/// "Myself" or "Someone else".
final class RunnerForSomeoneElseChanged extends RunnerDetailsEvent {
  const RunnerForSomeoneElseChanged(this.forSomeoneElse);

  final bool forSomeoneElse;

  @override
  List<Object?> get props => [forSomeoneElse];
}

/// The form's text fields.
enum RunnerField { name, phone, email, age, nationality, emergencyName, emergencyPhone }

final class RunnerTextChanged extends RunnerDetailsEvent {
  const RunnerTextChanged(this.field, this.value);

  final RunnerField field;
  final String value;

  @override
  List<Object?> get props => [field, value];
}

final class RunnerGenderChosen extends RunnerDetailsEvent {
  const RunnerGenderChosen(this.gender);

  final Gender gender;

  @override
  List<Object?> get props => [gender];
}

final class RunnerShirtSizeChosen extends RunnerDetailsEvent {
  const RunnerShirtSizeChosen(this.size);

  final ShirtSize size;

  @override
  List<Object?> get props => [size];
}

/// The "Save to my account" switch.
final class RunnerSaveChanged extends RunnerDetailsEvent {
  const RunnerSaveChanged(this.save);

  final bool save;

  @override
  List<Object?> get props => [save];
}
