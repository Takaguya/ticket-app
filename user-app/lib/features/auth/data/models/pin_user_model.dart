import '../../domain/entities/gender.dart';
import '../../domain/entities/pin_user.dart';

/// [PinUser] as JSON:
/// `{"id", "name", "phone", "gender": "female", "dateOfBirth": "1996-04-12", "email"}`
class PinUserModel {
  const PinUserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    this.email,
  });

  factory PinUserModel.fromJson(Map<String, dynamic> json) {
    return PinUserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      gender: Gender.values.byName(json['gender'] as String),
      dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
      email: json['email'] as String?,
    );
  }

  factory PinUserModel.fromEntity(PinUser user) {
    return PinUserModel(
      id: user.id,
      name: user.name,
      phone: user.phone,
      gender: user.gender,
      dateOfBirth: user.dateOfBirth,
      email: user.email,
    );
  }

  final String id;
  final String name;
  final String phone;
  final Gender gender;
  final DateTime dateOfBirth;
  final String? email;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'gender': gender.name,
    'dateOfBirth': isoDate(dateOfBirth),
    'email': ?email,
  };

  PinUser toEntity() {
    return PinUser(
      id: id,
      name: name,
      phone: phone,
      gender: gender,
      dateOfBirth: dateOfBirth,
      email: email,
    );
  }

  /// `1996-04-12`
  static String isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
