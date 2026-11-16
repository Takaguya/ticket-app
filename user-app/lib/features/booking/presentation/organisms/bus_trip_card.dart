import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/domain/entities/bus_departure.dart';
import '../../../catalog/presentation/organisms/bus_journey.dart';
import '../../domain/entities/seat_map.dart';

/// A bus booking's trip: the operator and coach, when it leaves and
/// arrives, the seats, and the station to get on at.
class BusTripCard extends StatelessWidget {
  const BusTripCard({super.key, required this.departure, required this.seats});

  final BusDeparture departure;
  final List<Seat> seats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                  color: Color(departure.operatorColor),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  departure.operatorCode,
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
                    Text(departure.operatorName, style: AppTextStyles.bodyStrong),
                    Text(departure.coachType, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BusJourney(departure: departure),
          const SizedBox(height: 14),
          Text(
            seats.length == 1 ? '1 SEAT' : '${seats.length} SEATS',
            style: AppTextStyles.fieldLabel,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final seat in seats) _SeatChip(seat: seat)],
          ),
          const Divider(height: 26, color: AppColors.divider),
          Row(
            children: [
              const IconTile(
                icon: Icons.place_outlined,
                background: AppColors.primarySoft,
                foreground: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Get on at ${departure.boardingPoint}', style: AppTextStyles.bodyStrong),
                    Text(departure.boardingAddress, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "3A  Row 3 · Window"
class _SeatChip extends StatelessWidget {
  const _SeatChip({required this.seat});

  final Seat seat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_seat_outlined, size: 15, color: AppColors.ink),
          const SizedBox(width: 6),
          Text(seat.id, style: AppTextStyles.bodyStrong),
          const SizedBox(width: 6),
          Text(seat.detail, style: AppTextStyles.bodySmall.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
