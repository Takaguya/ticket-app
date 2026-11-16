import 'package:equatable/equatable.dart';

/// One line of an order: tickets of one kind, a set of seats, or a snack.
class OrderLine extends Equatable {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    this.isTicket = true,
  });

  /// e.g. "VIP", "Seats 3A, 4A" or "Popcorn combo".
  final String name;
  final int quantity;

  /// Whole US cents each; 0 is free.
  final int unitPriceCents;

  /// False for extras such as snacks, which do not count as tickets.
  final bool isTicket;

  int get totalCents => quantity * unitPriceCents;

  @override
  List<Object?> get props => [name, quantity, unitPriceCents, isTicket];
}
