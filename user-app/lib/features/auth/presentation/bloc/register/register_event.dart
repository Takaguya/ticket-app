part of 'register_bloc.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

final class RegisterNameChanged extends RegisterEvent {
  const RegisterNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class RegisterGenderChanged extends RegisterEvent {
  const RegisterGenderChanged(this.gender);

  final Gender gender;

  @override
  List<Object?> get props => [gender];
}

final class RegisterDateOfBirthChanged extends RegisterEvent {
  const RegisterDateOfBirthChanged(this.dateOfBirth);

  final DateTime dateOfBirth;

  @override
  List<Object?> get props => [dateOfBirth];
}

final class RegisterEmailChanged extends RegisterEvent {
  const RegisterEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// The person tapped "Create account".
final class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted();
}
