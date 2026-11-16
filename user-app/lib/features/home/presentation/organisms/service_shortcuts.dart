import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';

/// What Pin offers: Tickets now, Ride and Food soon.
class ServiceShortcuts extends StatelessWidget {
  const ServiceShortcuts({super.key, required this.onTickets, required this.onComingSoon});

  final VoidCallback onTickets;

  /// Tapped Ride or Food, which are not available yet; gets the service's name.
  final ValueChanged<String> onComingSoon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _Service(
              label: 'Tickets',
              icon: Icons.confirmation_number_outlined,
              background: AppColors.primarySoft,
              foreground: AppColors.primary,
              onTap: onTickets,
            ),
          ),
          Expanded(
            child: _Service(
              label: 'Ride',
              icon: Icons.directions_car_outlined,
              background: AppColors.rideSoft,
              foreground: AppColors.ride,
              soon: true,
              onTap: () => onComingSoon('Ride'),
            ),
          ),
          Expanded(
            child: _Service(
              label: 'Food',
              icon: Icons.restaurant_outlined,
              background: AppColors.dangerSoft,
              foreground: AppColors.danger,
              soon: true,
              onTap: () => onComingSoon('Food'),
            ),
          ),
          // The design leaves room for a fourth service.
          const Spacer(),
        ],
      ),
    );
  }
}

class _Service extends StatelessWidget {
  const _Service({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.soon = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: soon ? '$label, coming soon' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconTile(
                  icon: icon,
                  background: background,
                  foreground: foreground,
                  size: 52,
                  shape: IconTileShape.circle,
                ),
                if (soon) const Positioned(right: -14, top: -6, child: AppBadge(label: 'Soon')),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
