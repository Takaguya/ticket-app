import 'package:equatable/equatable.dart';

import 'ticket_category.dart';

/// Which categories can be bought right now. The mock catalogue sells all
/// four, and so does the Pin API (cinema without snacks). A category that is
/// not on sale shows as "Coming soon" and does not open.
class AvailableCategories extends Equatable {
  const AvailableCategories(this.onSale, {this.sellsSnacks = true});

  /// Everything is on sale.
  static const all = AvailableCategories({
    TicketCategory.events,
    TicketCategory.bus,
    TicketCategory.cinema,
    TicketCategory.admission,
  });

  /// Events only: what the Pin API sold before bus trips.
  static const eventsOnly = AvailableCategories({TicketCategory.events});

  /// Events and bus trips: what the Pin API sold before cinema.
  static const eventsAndBuses = AvailableCategories({TicketCategory.events, TicketCategory.bus});

  /// What the Pin API sells today: everything, with no cinema snacks.
  static const pinApi = AvailableCategories({
    TicketCategory.events,
    TicketCategory.bus,
    TicketCategory.cinema,
    TicketCategory.admission,
  }, sellsSnacks: false);

  /// What the Pin API sold before places: events, bus trips and cinema.
  static const withoutPlaces = AvailableCategories({
    TicketCategory.events,
    TicketCategory.bus,
    TicketCategory.cinema,
  }, sellsSnacks: false);

  final Set<TicketCategory> onSale;

  /// A cinema booking offers snacks after the seats. The Pin API sells none, so
  /// there booking goes from the seats straight to checkout.
  final bool sellsSnacks;

  bool isOnSale(TicketCategory category) => onSale.contains(category);

  @override
  List<Object?> get props => [onSale, sellsSnacks];
}
