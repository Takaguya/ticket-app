part of 'runner_details_bloc.dart';

enum RunnerDetailsStatus {
  /// Looking for runner details saved to the account.
  loading,
  ready,
}

final class RunnerDetailsState extends Equatable {
  const RunnerDetailsState({
    this.status = RunnerDetailsStatus.loading,
    this.forSomeoneElse = false,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.gender,
    this.age = '',
    this.nationality = '',
    this.shirtSize,
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.saveToAccount = true,
    this.filledFromSaved = false,
    this.formVersion = 0,
  });

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final RunnerDetailsStatus status;

  /// Registering someone other than the signed-in person.
  final bool forSomeoneElse;
  final String name;

  /// As typed, without +855.
  final String phone;

  /// Optional.
  final String email;
  final Gender? gender;

  /// As typed.
  final String age;
  final String nationality;
  final ShirtSize? shirtSize;
  final String emergencyName;

  /// As typed, without +855.
  final String emergencyPhone;

  /// The "Save to my account" switch. Only the person's own details are saved.
  final bool saveToAccount;

  /// The form was filled from runner details saved at an earlier race.
  final bool filledFromSaved;

  /// Goes up each time the bloc refills the form, so the text fields start
  /// again from the new values.
  final int formVersion;

  /// What is missing or wrong, the first in the form's order, or null when
  /// the details are complete.
  String? get problem {
    if (name.trim().length < 2) return "Enter the runner's full name";
    if (gender == null) return "Choose the runner's gender";
    final years = int.tryParse(age.trim());
    if (years == null || years < RunnerDetails.minAge || years > RunnerDetails.maxAge) {
      return 'Enter an age from ${RunnerDetails.minAge} to ${RunnerDetails.maxAge}';
    }
    if (nationality.trim().length < 2) return 'Enter the nationality';
    if (!PhoneNumber.isValid(phone)) return 'Enter a valid phone number';
    if (email.trim().isNotEmpty && !_emailShape.hasMatch(email.trim())) {
      return 'Enter a valid email, or leave it empty';
    }
    if (shirtSize == null) return 'Choose a T-shirt size';
    if (emergencyName.trim().length < 2) return 'Enter an emergency contact';
    if (!PhoneNumber.isValid(emergencyPhone)) return "Enter the emergency contact's phone number";
    return null;
  }

  /// The details, or null while [problem] is set.
  RunnerDetails? get runner {
    if (problem != null) return null;
    final typedEmail = email.trim();
    return RunnerDetails(
      name: name.trim(),
      phone: PhoneNumber.toE164(phone),
      email: typedEmail.isEmpty ? null : typedEmail,
      gender: gender!,
      age: int.parse(age.trim()),
      nationality: nationality.trim(),
      emergencyName: emergencyName.trim(),
      emergencyPhone: PhoneNumber.toE164(emergencyPhone),
      shirtSize: shirtSize!,
    );
  }

  /// Whether placing the order keeps these details on the account.
  bool get savesToAccount => !forSomeoneElse && saveToAccount;

  RunnerDetailsState copyWith({
    RunnerDetailsStatus? status,
    String? name,
    String? phone,
    String? email,
    Gender? gender,
    String? age,
    String? nationality,
    ShirtSize? shirtSize,
    String? emergencyName,
    String? emergencyPhone,
    bool? saveToAccount,
  }) {
    return RunnerDetailsState(
      status: status ?? this.status,
      forSomeoneElse: forSomeoneElse,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      nationality: nationality ?? this.nationality,
      shirtSize: shirtSize ?? this.shirtSize,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      saveToAccount: saveToAccount ?? this.saveToAccount,
      filledFromSaved: filledFromSaved,
      formVersion: formVersion,
    );
  }

  @override
  List<Object?> get props => [
    status,
    forSomeoneElse,
    name,
    phone,
    email,
    gender,
    age,
    nationality,
    shirtSize,
    emergencyName,
    emergencyPhone,
    saveToAccount,
    filledFromSaved,
    formVersion,
  ];
}
