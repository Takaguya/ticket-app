import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/date_tile.dart';
import '../../../../design_system/molecules/list_row.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../auth/domain/entities/business_type.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/entities/sales_summary.dart';
import '../../../events/domain/entities/event.dart';
import 'event_thumbnail.dart';

/// Upcoming events with how many tickets each has sold, and the
/// "Create event" button ("Create trip" for a bus company).
class UpcomingEventsCard extends StatelessWidget {
  const UpcomingEventsCard({
    super.key,
    required this.events,
    required this.summaryOf,
    required this.onOpen,
    required this.onCreate,
    this.onEditPicture,
    this.businessType = BusinessType.events,
  });

  final List<Event> events;
  final SalesSummary Function(Event event) summaryOf;
  final ValueChanged<Event> onOpen;
  final VoidCallback onCreate;

  /// The owner's view: opens the sheet to add or change an event's picture.
  /// Null hides the camera mark.
  final ValueChanged<Event>? onEditPicture;

  /// A bus company publishes trips and a cinema screenings, not events.
  final BusinessType businessType;

  @override
  Widget build(BuildContext context) {
    // What this business publishes, in the plural and the singular.
    final (plural, singular) = switch (businessType) {
      BusinessType.bus => ('trips', 'trip'),
      BusinessType.cinema => ('screenings', 'screening'),
      BusinessType.admission => ('places', 'place'),
      _ => ('events', 'event'),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Upcoming $plural', style: AppTextStyles.sectionTitle),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No upcoming $plural yet.', style: AppTextStyles.bodySmall),
            ),
          for (final event in events)
            ListRow(
              leading: EventThumbnail(
                event: event,
                onEditPicture: onEditPicture == null ? null : () => onEditPicture!(event),
                fallback: event.isPlace
                    ? const DateTile(caption: 'Open', day: 'All')
                    : DateTile(
                        caption: DateFormat.month(event.startsAt),
                        day: '${event.startsAt.day}',
                      ),
              ),
              title: event.name,
              subtitle: event.isPlace
                  ? '${event.kind.label} · Every day · ${event.venue}'
                  : '${event.kind.label} · ${DateFormat.time(event.startsAt)} · ${event.venue}',
              trailing: event.approved
                  ? Text(
                      switch (summaryOf(event).sold) {
                        0 => 'On sale',
                        final sold => '$sold sold',
                      },
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const AppBadge(
                      label: 'Awaiting approval',
                      backgroundColor: AppColors.warningSoft,
                      foregroundColor: AppColors.warning,
                    ),
              onTap: () => onOpen(event),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Create $singular',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.tonal,
            height: 48,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

/// Finished events with their sold and attended counts.
class PastEventsCard extends StatelessWidget {
  const PastEventsCard({
    super.key,
    required this.events,
    required this.summaryOf,
    required this.onOpen,
  });

  final List<Event> events;
  final SalesSummary Function(Event event) summaryOf;
  final ValueChanged<Event> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Past events', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          for (final (index, event) in events.indexed)
            ListRow(
              minHeight: 64,
              showDivider: index < events.length - 1,
              leading: DateTile(
                caption: DateFormat.month(event.startsAt),
                day: '${event.startsAt.day}',
                style: DateTileStyle.past,
              ),
              title: event.name,
              subtitle: switch (summaryOf(event)) {
                final summary =>
                  '${event.kind.label} · ${summary.sold} sold · ${summary.checkedIn} attended',
              },
              trailing: const Text(
                'Bookings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              onTap: () => onOpen(event),
            ),
        ],
      ),
    );
  }
}

/// The five most recent check-ins.
class LatestCheckInsCard extends StatelessWidget {
  const LatestCheckInsCard({
    super.key,
    required this.bookings,
    required this.currentUserName,
    required this.onOpen,
    required this.onSeeAll,
  });

  /// Checked-in bookings, newest first.
  final List<Booking> bookings;

  /// Shown as "you" when this person did the check-in.
  final String currentUserName;
  final ValueChanged<Booking> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Latest check-ins', style: AppTextStyles.sectionTitle)),
              TextButton(
                onPressed: onSeeAll,
                child: const Text(
                  'All bookings',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (bookings.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Nobody has checked in yet.', style: AppTextStyles.bodySmall),
            ),
          for (final (index, booking) in bookings.indexed)
            ListRow(
              minHeight: 52,
              showDivider: index < bookings.length - 1,
              titleWeight: FontWeight.w700,
              title: booking.buyerName,
              subtitle: switch (booking.checkIn?.staffName) {
                null => booking.summary,
                final name => '${booking.summary} · by ${name == currentUserName ? 'you' : name}',
              },
              trailing: Text(
                booking.checkIn == null ? '' : DateFormat.time(booking.checkIn!.at),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              onTap: () => onOpen(booking),
            ),
        ],
      ),
    );
  }
}
