part of 'register_business_bloc.dart';

sealed class RegisterBusinessEvent extends Equatable {
  const RegisterBusinessEvent();

  @override
  List<Object?> get props => [];
}

final class RegisterBusinessNameChanged extends RegisterBusinessEvent {
  const RegisterBusinessNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class RegisterContactNameChanged extends RegisterBusinessEvent {
  const RegisterContactNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class RegisterBusinessTypeChanged extends RegisterBusinessEvent {
  const RegisterBusinessTypeChanged(this.type);

  final BusinessType type;

  @override
  List<Object?> get props => [type];
}

/// The person tapped "Create account".
final class RegisterBusinessSubmitted extends RegisterBusinessEvent {
  const RegisterBusinessSubmitted();
}
