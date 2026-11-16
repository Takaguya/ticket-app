import 'package:equatable/equatable.dart';

/// A promo code, e.g. D2D10 for 10% off. Either a percentage or a fixed
/// amount comes off, never more than the order costs.
class Promotion extends Equatable {
  const Promotion({
    required this.code,
    required this.title,
    required this.description,
    this.percentOff = 0,
    this.amountOffCents = 0,
    this.minimumSpendCents = 0,
  });

  /// What the person types, e.g. "D2D10".
  final String code;

  /// e.g. "10% off tickets".
  final String title;

  /// e.g. "Any category".
  final String description;
  final int percentOff;
  final int amountOffCents;

  /// The order must cost at least this much, in whole US cents.
  final int minimumSpendCents;

  bool appliesTo(int subtotalCents) => subtotalCents > 0 && subtotalCents >= minimumSpendCents;

  /// How much comes off an order of [subtotalCents], in whole US cents.
  int discountOn(int subtotalCents) {
    if (!appliesTo(subtotalCents)) return 0;
    final off = (subtotalCents * percentOff / 100).round() + amountOffCents;
    return off > subtotalCents ? subtotalCents : off;
  }

  /// Codes are not case sensitive.
  bool matches(String typed) => typed.trim().toUpperCase() == code.toUpperCase();

  @override
  List<Object?> get props => [code, title, description, percentOff, amountOffCents, minimumSpendCents];
}
