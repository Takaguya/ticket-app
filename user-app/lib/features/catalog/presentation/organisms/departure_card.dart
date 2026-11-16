import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/bus_departure.dart';
import 'bus_journey.dart';

/// One bus: the operator, when it leaves and arrives, the fare, what is on
/// board and how many seats are left.
class DepartureCard extends StatelessWidget {
  const DepartureCard({super.key, required this.departure, required this.onTap});

  final BusDeparture departure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = departure;
    final seatsLeft = d.seatsLeft == 1 ? '1 seat left' : '${d.seatsLeft} seats left';
    return Semantics(
      button: true,
      label: '${d.operatorName}, leaves ${DateFormat.time(d.departsAt)}, arrives '
          '${DateFormat.time(d.arrivesAt)}, ${Money.format(d.priceCents)}, $seatsLeft',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(d.operatorColor),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    d.operatorCode,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.operatorName, style: AppTextStyles.bodyStrong),
                      Row(
                        children: [
                          const Icon(Icons.event_seat_outlined, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              d.coachType,
                              style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(Money.format(d.priceCents), style: AppTextStyles.price.copyWith(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 14),
            BusJourney(departure: d),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.amenities.join(' · '),
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5),
                  ),
                ),
                Text(
                  seatsLeft,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: d.isNearlyFull ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

