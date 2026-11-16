part of 'register_bloc.dart';

enum RegisterStatus {
  idle,
  submitting,

  /// The account was created and the person is signed in.
  registered,

  /// Show [RegisterState.errorMessage].
  failure,
}

final class RegisterState extends Equatable {
  const RegisterState({
    this.name = '',
    this.gender,
    this.dateOfBirth,
    this.email = '',
    this.status = RegisterStatus.idle,
    this.errorMessage,
  });

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final String name;
  final Gender? gender;
  final DateTime? dateOfBirth;

  /// Optional.
  final String email;
  final RegisterStatus status;
  final String? errorMessage;

  bool get isNameValid => name.trim().length >= 2;
  bool get isEmailValid => email.trim().isEmpty || _emailShape.hasMatch(email.trim());

  /// What is still missing or wrong, in the order of the form; null when the
  /// details can be sent.
  String? get firstProblem {
    if (!isNameValid) return 'Please enter your name';
    if (gender == null) return 'Please choose a gender';
    if (dateOfBirth == null) return 'Please enter your date of birth';
    if (!isEmailValid) return 'Please enter a valid email';
    return null;
  }

  bool get canSubmit => firstProblem == null;
  bool get isSubmitting => status == RegisterStatus.submitting;

  /// "Sokha" for "Sokha Chan", for the welcome message.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  RegisterState copyWith({
    String? name,
    Gender? gender,
    DateTime? dateOfBirth,
    String? email,
    RegisterStatus? status,
    String? errorMessage,
  }) {
    return RegisterState(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      email: email ?? this.email,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [name, gender, dateOfBirth, email, status, errorMessage];
}
