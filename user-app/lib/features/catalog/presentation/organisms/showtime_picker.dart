import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/molecules/day_strip.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/showtime.dart';

/// A row of days to choose from, then each cinema with its times that day.
class ShowtimePicker extends StatelessWidget {
  const ShowtimePicker({
    super.key,
    required this.days,
    required this.today,
    required this.selectedDay,
    required this.onDaySelected,
    required this.theatres,
    required this.loading,
    required this.selectedShowtimeId,
    required this.onShowtimeSelected,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// The cinemas showing the film on [selectedDay].
  final List<TheatreShowtimes> theatres;

  /// The times for [selectedDay] are loading.
  final bool loading;
  final String? selectedShowtimeId;
  final ValueChanged<Showtime> onShowtimeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayStrip(days: days, today: today, selected: selectedDay, onSelected: onDaySelected),
        const SizedBox(height: AppSpacing.md),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (theatres.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'No more showtimes on this day. Choose another day.',
              style: AppTextStyles.bodySmall,
            ),
          )
        else
          for (final theatre in theatres) ...[
            Text(theatre.theatre.name, style: AppTextStyles.bodyStrong),
            Text(theatre.theatre.area, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final show in theatre.showtimes)
                  _TimeChip(
                    show: show,
                    selected: show.id == selectedShowtimeId,
                    onTap: () => onShowtimeSelected(show),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.show, required this.selected, required this.onTap});

  final Showtime show;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.input);
    final time = DateFormat.time(show.startsAt);
    return Semantics(
      button: true,
      selected: selected,
      label: '$time, ${show.hall}, ${Money.format(show.priceCents)}',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.borderSoft),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.surface : AppColors.ink,
                  ),
                ),
                Text(
                  '${show.hall} · ${Money.format(show.priceCents)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primarySoft : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
