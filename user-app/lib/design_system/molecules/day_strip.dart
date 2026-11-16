import 'package:flutter/material.dart';

import '../../core/utils/date_format.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// A row of days that scrolls sideways: "Today 15", "Mon 16", "Tue 17"...
/// One is chosen.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.today,
    required this.selected,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final day = days[index];
          final isToday = DateFormat.dateOnly(day) == DateFormat.dateOnly(today);
          return _DayChip(
            label: isToday ? 'Today' : DateFormat.weekday(day),
            day: '${day.day}',
            semanticLabel: DateFormat.relativeDay(day, today: today),
            selected: DateFormat.dateOnly(day) == DateFormat.dateOnly(selected),
            onTap: () => onSelected(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.day,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String day;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.input);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.borderSoft,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(day, style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
