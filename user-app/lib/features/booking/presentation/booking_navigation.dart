import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../catalog/domain/entities/listing.dart';
import '../domain/entities/booking.dart';
import '../domain/entities/booking_request.dart';

/// The way through booking, the same from every page:
///
/// * event or place: tickets, (a race: the runner), checkout;
/// * bus: seats, checkout;
/// * film: seats, snacks (when sold), checkout;
///
/// then the ticket.
extension BookingNavigation on BuildContext {
  /// "Select tickets" on an event or a place.
  void selectTickets(Listing listing) => pushNamed(AppRoutes.selectTickets, extra: listing);

  /// A bus departure or a showtime, with no seats chosen yet.
  void chooseSeats(BookingRequest request) => pushNamed(AppRoutes.seats, extra: request);

  /// After the tickets: the runner for a race, otherwise checkout.
  void continueWithTickets(BookingRequest request) {
    if (request is EventRequest && request.event.needsRunnerDetails) {
      pushNamed(AppRoutes.runnerDetails, extra: request);
    } else {
      openCheckout(request);
    }
  }

  /// After the seats: snacks for a film when they are sold ([sellsSnacks]),
  /// otherwise checkout.
  void continueWithSeats(BookingRequest request, {required bool sellsSnacks}) {
    if (request is CinemaRequest && sellsSnacks) {
      pushNamed(AppRoutes.snacks, extra: request);
    } else {
      openCheckout(request);
    }
  }

  void openCheckout(BookingRequest request, {bool saveRunner = false}) {
    pushNamed(
      AppRoutes.checkout,
      extra: CheckoutRouteArgs(request: request, saveRunner: saveRunner),
    );
  }

  /// After paying: the new ticket, over the Activity tab, so "back" shows it
  /// in the list rather than the booking steps.
  void showIssuedTicket(Booking booking) {
    goNamed(
      AppRoutes.ticket,
      pathParameters: {AppRoutes.bookingIdParam: booking.id},
      extra: TicketRouteArgs(booking: booking, justIssued: true),
    );
  }

  void openTicket(Booking booking) {
    pushNamed(
      AppRoutes.ticket,
      pathParameters: {AppRoutes.bookingIdParam: booking.id},
      extra: TicketRouteArgs(booking: booking),
    );
  }
}
