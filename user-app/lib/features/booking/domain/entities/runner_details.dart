import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/gender.dart';

/// Race kit T-shirt sizes.
enum ShirtSize {
  xs('XS'),
  s('S'),
  m('M'),
  l('L'),
  xl('XL');

  const ShirtSize(this.label);

  final String label;
}

/// Who runs a race. The organiser needs more than a name: the age group,
/// the race kit's shirt size and someone to call if something happens on
/// the course.
class RunnerDetails extends Equatable {
  const RunnerDetails({
    required this.name,
    required this.phone,
    required this.gender,
    required this.age,
    required this.nationality,
    required this.emergencyName,
    required this.emergencyPhone,
    required this.shirtSize,
    this.email,
  });

  static const minAge = 5;
  static const maxAge = 99;

  final String name;

  /// E.164 form, e.g. `+85510222333`.
  final String phone;

  /// Where the e-ticket is also sent. Optional.
  final String? email;
  final Gender gender;
  final int age;

  /// e.g. "Cambodian".
  final String nationality;
  final String emergencyName;

  /// E.164 form.
  final String emergencyPhone;
  final ShirtSize shirtSize;

  @override
  List<Object?> get props => [
    name,
    phone,
    email,
    gender,
    age,
    nationality,
    emergencyName,
    emergencyPhone,
    shirtSize,
  ];
}
