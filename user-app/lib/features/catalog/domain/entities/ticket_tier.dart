import 'package:equatable/equatable.dart';

/// One kind of ticket for an event or a place, e.g. "VIP · Seated balcony ·
/// free drink · $35".
class TicketTier extends Equatable {
  const TicketTier({required this.name, required this.priceCents, this.description = ''});

  final String name;

  /// What the ticket includes, e.g. "Standing floor". May be empty.
  final String description;

  /// Whole US cents; 0 is free.
  final int priceCents;

  @override
  List<Object?> get props => [name, description, priceCents];
}
