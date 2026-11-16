import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/date_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/presentation/category_style.dart';
import '../../domain/entities/booking.dart';
import '../booking_text.dart';

/// One booking in the Activity list: the date, what and where, its status,
/// the booking ID, the number of tickets and what was paid.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.isPast,
    required this.onTap,
  });

  final Booking booking;
  final bool isPast;
  final VoidCallback onTap;

  /// Cancelled and used say more than whether the day has gone.
  Widget _statusBadge() {
    if (booking.isCancelled) {
      return const AppBadge(
        label: 'Cancelled',
        backgroundColor: AppColors.dangerSoft,
        foregroundColor: AppColors.danger,
      );
    }
    if (booking.isUsed) {
      return const AppBadge(
        label: 'Used',
        backgroundColor: AppColors.fill,
        foregroundColor: AppColors.textMuted,
      );
    }
    return isPast
        ? const AppBadge(
            label: 'Ended',
            backgroundColor: AppColors.fill,
            foregroundColor: AppColors.textMuted,
          )
        : const AppBadge(
            label: 'Confirmed',
            backgroundColor: AppColors.successSoft,
            foregroundColor: AppColors.success,
          );
  }

  @override
  Widget build(BuildContext context) {
    final request = booking.request;
    final startsAt = request.startsAt;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateTile(
                  month: DateFormat.month(startsAt),
                  day: '${startsAt.day}',
                  style: DateTileStyle.dark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          request.tagBadge(),
                          const Spacer(),
                          _statusBadge(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(request.title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15.5)),
                      Text(
                        '${request.timeText} · ${request.place}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${booking.id} · ${request.ticketCountText}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                  Text(Money.format(booking.totalCents), style: AppTextStyles.price),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
