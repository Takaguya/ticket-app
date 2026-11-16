import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/bus_departure.dart';

/// When a bus leaves and where from, the journey time, and when and where it
/// arrives: "07:45 Phnom Penh ——6h——• 13:45 Siem Reap".
class BusJourney extends StatelessWidget {
  const BusJourney({super.key, required this.departure});

  final BusDeparture departure;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stop(time: DateFormat.time(departure.departsAt), place: departure.origin),
        Expanded(child: _Line(duration: DateFormat.duration(departure.duration))),
        _Stop(
          time: DateFormat.time(departure.arrivesAt),
          place: departure.destination,
          alignEnd: true,
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.time, required this.place, this.alignEnd = false});

  final String time;
  final String place;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(time, style: AppTextStyles.title.copyWith(fontSize: 19)),
        Text(place, style: AppTextStyles.bodySmall.copyWith(fontSize: 12)),
      ],
    );
  }
}

/// The line between the two stops, with the journey time above it.
class _Line extends StatelessWidget {
  const _Line({required this.duration});

  final String duration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Text(duration, style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Divider(height: 2, thickness: 2, color: AppColors.divider)),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
