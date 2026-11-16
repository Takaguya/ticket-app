import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/seat_map.dart';

/// A bus's or a hall's seats, row by row, with the front of the bus or the
/// screen at the top and a key at the bottom. Free seats can be tapped; on
/// buses, taken seats show whether a woman or a man sits there.
class SeatMapView extends StatelessWidget {
  const SeatMapView({
    super.key,
    required this.seatMap,
    required this.isSelected,
    required this.onSeatTapped,
  });

  final SeatMap seatMap;
  final bool Function(Seat seat) isSelected;
  final ValueChanged<Seat> onSeatTapped;

  @override
  Widget build(BuildContext context) {
    final cinema = seatMap.hasScreen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Front(cinema: cinema),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = seatMap.rows.isEmpty ? 1 : seatMap.rows.first.length;
            final gap = cinema ? 4.0 : 8.0;
            final size = ((constraints.maxWidth - gap * (columns - 1)) / columns).clamp(18.0, 40.0);
            return Column(
              children: [
                for (final row in seatMap.rows)
                  Padding(
                    padding: EdgeInsets.only(bottom: gap + 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final (index, seat) in row.indexed) ...[
                          if (index > 0) SizedBox(width: gap),
                          if (seat == null)
                            SizedBox(width: size)
                          else
                            _SeatCell(
                              key: ValueKey('seat-${seat.id}'),
                              seat: seat,
                              size: size,
                              selected: isSelected(seat),
                              onTap: () => onSeatTapped(seat),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _Key(showPassengers: !cinema),
      ],
    );
  }
}

/// The screen above a hall's first row, or the front of a bus.
class _Front extends StatelessWidget {
  const _Front({required this.cinema});

  final bool cinema;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      cinema ? 'SCREEN' : 'FRONT · DRIVER',
      textAlign: TextAlign.center,
      style: AppTextStyles.fieldLabel.copyWith(fontSize: 11, letterSpacing: 2),
    );
    if (!cinema) return label;
    return Column(
      children: [
        Container(
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(
              colors: [AppColors.border, AppColors.ink, AppColors.border],
            ),
          ),
        ),
        const SizedBox(height: 6),
        label,
      ],
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    super.key,
    required this.seat,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final Seat seat;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (seat.status) {
      _ when selected => (AppColors.primary, AppColors.primary, AppColors.surface),
      SeatStatus.available => (AppColors.surface, AppColors.seatBorder, AppColors.ink),
      SeatStatus.taken => (AppColors.seatTaken, AppColors.seatTaken, AppColors.onSeatTaken),
      SeatStatus.takenByFemale => (
        AppColors.seatFemaleSoft,
        AppColors.seatFemaleBorder,
        AppColors.seatFemale,
      ),
      SeatStatus.takenByMale => (
        AppColors.seatMaleSoft,
        AppColors.seatMaleBorder,
        AppColors.seatMale,
      ),
    };
    final icon = switch (seat.status) {
      SeatStatus.takenByFemale => Icons.female_rounded,
      SeatStatus.takenByMale => Icons.male_rounded,
      SeatStatus.available || SeatStatus.taken => null,
    };
    final state = switch (seat.status) {
      _ when selected => 'chosen',
      SeatStatus.available => 'free',
      SeatStatus.taken => 'taken',
      SeatStatus.takenByFemale => 'taken by a woman',
      SeatStatus.takenByMale => 'taken by a man',
    };
    final radius = BorderRadius.circular(size / 5);

    return Semantics(
      button: !seat.status.isTaken,
      selected: selected,
      label: 'Seat ${seat.id}, $state',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: border)),
        child: InkWell(
          onTap: seat.status.isTaken ? null : onTap,
          borderRadius: radius,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: size * 0.55, color: foreground)
                  : Text(
                      seat.label,
                      style: TextStyle(
                        fontSize: size * 0.32,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the colours mean.
class _Key extends StatelessWidget {
  const _Key({required this.showPassengers});

  final bool showPassengers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        const _KeyItem(color: AppColors.surface, border: AppColors.seatBorder, label: 'Available'),
        const _KeyItem(color: AppColors.primary, border: AppColors.primary, label: 'Selected'),
        if (showPassengers) ...const [
          _KeyItem(
            color: AppColors.seatFemaleSoft,
            border: AppColors.seatFemaleBorder,
            icon: Icons.female_rounded,
            iconColor: AppColors.seatFemale,
            label: 'Female passenger',
          ),
          _KeyItem(
            color: AppColors.seatMaleSoft,
            border: AppColors.seatMaleBorder,
            icon: Icons.male_rounded,
            iconColor: AppColors.seatMale,
            label: 'Male passenger',
          ),
        ] else
          const _KeyItem(color: AppColors.seatTaken, border: AppColors.seatTaken, label: 'Taken'),
      ],
    );
  }
}

class _KeyItem extends StatelessWidget {
  const _KeyItem({
    required this.color,
    required this.border,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final Color color;
  final Color border;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: icon == null ? null : Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5)),
      ],
    );
  }
}
