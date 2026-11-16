import 'package:equatable/equatable.dart';

import 'gender.dart';

/// Someone who books tickets with Pin.
class PinUser extends Equatable {
  const PinUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    this.email,
  });

  final String id;
  final String name;

  /// E.164 form, e.g. `+85510222333`.
  final String phone;
  final Gender gender;
  final DateTime dateOfBirth;

  /// Optional at registration.
  final String? email;

  /// "Sokha" for "Sokha Chan", for greetings.
  String get firstName {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.first.isEmpty ? name : words.first;
  }

  @override
  List<Object?> get props => [id, name, phone, gender, dateOfBirth, email];
}
