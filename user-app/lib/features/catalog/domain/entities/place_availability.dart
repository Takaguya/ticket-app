import 'package:equatable/equatable.dart';

/// What is left of each kind of ticket of a place on one day. A place has an
/// optional limit per day for each kind of ticket; a kind with no limit has no
/// entry here.
class PlaceAvailability extends Equatable {
  const PlaceAvailability(this.left);

  /// Nothing is limited: what the mock catalogue answers.
  static const unlimited = PlaceAvailability({});

  /// How many are left, by ticket name. Only kinds with a limit are listed.
  final Map<String, int> left;

  /// How many of [ticket] are left that day, or null when it has no limit.
  int? leftOf(String ticket) => left[ticket];

  bool isSoldOut(String ticket) => left[ticket] == 0;

  @override
  List<Object?> get props => [left];
}
