import 'package:flutter/material.dart';

import '../../../design_system/atoms/app_badge.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../booking/domain/entities/booking_request.dart';
import '../domain/entities/event_kind.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/ticket_category.dart';

/// How a category looks: its icon and colours, as in the prototype.
extension TicketCategoryStyle on TicketCategory {
  IconData get icon => switch (this) {
    TicketCategory.events => Icons.music_note_outlined,
    TicketCategory.bus => Icons.directions_bus_outlined,
    TicketCategory.cinema => Icons.movie_outlined,
    TicketCategory.admission => Icons.confirmation_number_outlined,
  };

  /// The soft background of the category's tag and button.
  Color get softColor => switch (this) {
    TicketCategory.events => AppColors.eventSoft,
    TicketCategory.bus => AppColors.busSoft,
    TicketCategory.cinema => AppColors.fill,
    TicketCategory.admission => AppColors.admissionSoft,
  };

  /// The icon colour on [softColor].
  Color get color => switch (this) {
    TicketCategory.events => AppColors.event,
    TicketCategory.bus => AppColors.bus,
    TicketCategory.cinema => AppColors.inkSoft,
    TicketCategory.admission => AppColors.admission,
  };

  /// The small "Event" / "Bus" / "Cinema" / "Admission" label.
  AppBadge tagBadge() {
    return switch (this) {
      TicketCategory.events => AppBadge(
        label: tag,
        backgroundColor: AppColors.eventSoft,
        foregroundColor: AppColors.event,
      ),
      TicketCategory.bus => AppBadge(
        label: tag,
        backgroundColor: AppColors.busSoft,
        foregroundColor: AppColors.bus,
      ),
      TicketCategory.cinema => AppBadge(
        label: tag,
        backgroundColor: AppColors.cinemaSoft,
        foregroundColor: AppColors.cinema,
      ),
      TicketCategory.admission => AppBadge(
        label: tag,
        backgroundColor: AppColors.admissionSoft,
        foregroundColor: AppColors.admission,
      ),
    };
  }
}

/// How a kind of event looks: its own icon and label, in the events colours.
extension EventKindStyle on EventKind {
  IconData get icon => switch (this) {
    EventKind.marathon => Icons.directions_run_outlined,
    EventKind.concert => Icons.music_note_outlined,
    EventKind.show => Icons.theater_comedy_outlined,
  };

  AppBadge tagBadge() {
    return AppBadge(label: label, backgroundColor: AppColors.eventSoft, foregroundColor: AppColors.event);
  }
}

/// A listing's icon and tag: an event shows its kind, the rest their category.
extension ListingStyle on Listing {
  IconData get icon => switch (this) {
    EventListing(:final kind) => kind.icon,
    _ => category.icon,
  };

  AppBadge tagBadge() => switch (this) {
    EventListing(:final kind) => kind.tagBadge(),
    _ => category.tagBadge(),
  };
}

/// A booking's icon and tag, as for the [Listing] it is for.
extension BookingRequestStyle on BookingRequest {
  IconData get icon => switch (this) {
    EventRequest(:final event) => event.icon,
    _ => category.icon,
  };

  AppBadge tagBadge() => switch (this) {
    EventRequest(:final event) => event.tagBadge(),
    _ => category.tagBadge(),
  };
}
