import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/ticket_category.dart';

/// Where tapping a listing or a category leads, the same from every page.
extension CatalogNavigation on BuildContext {
  /// A bus route opens the bus search for that route; anything else its own page.
  void openListing(Listing listing) {
    switch (listing) {
      case BusRoute(:final id):
        pushNamed(AppRoutes.busTickets, queryParameters: {AppRoutes.routeQuery: id});
      case EventListing() || FilmListing() || AdmissionListing():
        pushNamed(AppRoutes.listing, pathParameters: {AppRoutes.listingIdParam: listing.id});
    }
  }

  /// Bus opens the bus search; the others their list.
  void openCategory(TicketCategory category) {
    if (category == TicketCategory.bus) {
      pushNamed(AppRoutes.busTickets);
    } else {
      pushNamed(AppRoutes.ticketCategory, pathParameters: {AppRoutes.categoryParam: category.path});
    }
  }

  void openTicketSearch() => pushNamed(AppRoutes.ticketSearch);
}
