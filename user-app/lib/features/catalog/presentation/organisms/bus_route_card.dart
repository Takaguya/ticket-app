import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/listing.dart';
import '../listing_text.dart';

/// A popular bus route: from, to, how long and how many operators, and the
/// cheapest fare.
class BusRouteCard extends StatelessWidget {
  const BusRouteCard({super.key, required this.route, required this.onTap});

  final BusRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final operators = route.operatorCount == 1 ? '1 operator' : '${route.operatorCount} operators';
    final details = '${DateFormat.duration(route.typicalDuration)} · $operators';
    return Semantics(
      button: true,
      label: '${route.origin} to ${route.destination}, $details, ${route.fromPriceText}',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const IconTile(
              icon: Icons.directions_bus_outlined,
              background: AppColors.busSoft,
              foreground: AppColors.bus,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(route.origin, style: AppTextStyles.bodyStrong)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMuted),
                      ),
                      Flexible(child: Text(route.destination, style: AppTextStyles.bodyStrong)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(details, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
            Text(route.fromPriceText, style: AppTextStyles.price.copyWith(fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}
