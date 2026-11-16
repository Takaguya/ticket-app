import 'package:equatable/equatable.dart';

/// Something to eat or drink, bought with cinema seats and picked up at the
/// counter with the ticket's QR code.
class Snack extends Equatable {
  const Snack({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
  });

  final String id;

  /// e.g. "Popcorn combo".
  final String name;

  /// e.g. "Large popcorn + 2 drinks".
  final String description;

  /// Whole US cents.
  final int priceCents;

  @override
  List<Object?> get props => [id, name, description, priceCents];
}
