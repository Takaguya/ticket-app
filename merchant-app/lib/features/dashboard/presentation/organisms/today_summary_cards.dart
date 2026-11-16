import 'package:flutter/widgets.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/app_progress_bar.dart';
import '../../../../design_system/atoms/date_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../bookings/domain/entities/sales_summary.dart';
import '../../../events/domain/entities/event.dart';
import 'event_thumbnail.dart';

const _caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted);
const _note = TextStyle(fontSize: 12.5, color: AppColors.textMuted);

/// "TODAY" tile with the live event's name, start time and venue.
class LiveEventCard extends StatelessWidget {
  const LiveEventCard({super.key, required this.event, this.onEditPicture});

  final Event event;

  /// The owner's view: opens the sheet to add or change the event's picture.
  final VoidCallback? onEditPicture;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // The event's picture, or its date tile. A place's date is only the day it was
          // published: it is open today, and every day.
          EventThumbnail(
            event: event,
            size: 52,
            onEditPicture: onEditPicture,
            fallback: DateTile(
              caption: event.isPlace ? 'Open' : 'Today',
              day: event.isPlace ? 'All' : '${event.startsAt.day}',
              style: DateTileStyle.highlight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  event.isPlace
                      ? '${event.kind.label} · Open every day · ${event.venue}'
                      : '${event.kind.label} · Starts ${DateFormat.time(event.startsAt)} · ${event.venue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _note,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (event.approved)
            const AppBadge(
              label: '● Live',
              backgroundColor: AppColors.successSoft,
              foregroundColor: AppColors.success,
            )
          else
            const AppBadge(
              label: 'Awaiting approval',
              backgroundColor: AppColors.warningSoft,
              foregroundColor: AppColors.warning,
            ),
        ],
      ),
    );
  }
}

/// The headline number: tickets checked in out of tickets sold.
class CheckedInCard extends StatelessWidget {
  const CheckedInCard({super.key, required this.summary});

  final SalesSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Checked in', style: _caption),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary.checkedIn}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              // Shrinks with large text settings instead of overflowing.
              Flexible(
                child: Text(
                  'of ${summary.sold} tickets',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(value: summary.checkedInFraction),
          const SizedBox(height: 8),
          Text('${ticketsLabel(summary.stillToArrive)} still to arrive', style: _note.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Two side-by-side tiles: sales and tickets sold.
class SalesStatsRow extends StatelessWidget {
  const SalesStatsRow({super.key, required this.summary});

  final SalesSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Sales',
            value: Money.format(summary.revenueCents),
            note: '${summary.bookingCount} bookings',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: summary.perDay ? 'Visitors today' : 'Tickets sold',
            value: '${summary.sold}',
            // A place has limits per ticket type per day, not a total to count down.
            note: summary.perDay ? 'for today' : '${summary.left} left of ${summary.capacity}',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _caption),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: _note),
        ],
      ),
    );
  }
}

/// Checked-in progress for each ticket type.
class TicketTypeBreakdown extends StatelessWidget {
  const TicketTypeBreakdown({super.key, required this.stats});

  final List<TicketTypeStats> stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('By ticket type', style: AppTextStyles.sectionTitle),
          for (final type in stats)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          type.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${type.checkedIn}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            TextSpan(text: ' / ${type.sold} in'),
                          ],
                        ),
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppProgressBar(
                    value: type.checkedInFraction,
                    height: 6,
                    trackColor: const Color(0xFFF0F0F0),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
