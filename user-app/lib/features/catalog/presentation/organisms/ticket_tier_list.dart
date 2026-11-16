import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/ticket_tier.dart';

/// The kinds of ticket on sale, each with what it includes and its price.
class TicketTierList extends StatelessWidget {
  const TicketTierList({super.key, required this.tiers});

  final List<TicketTier> tiers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiers.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tiers[i].name, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15)),
                      if (tiers[i].description.isNotEmpty)
                        Text(tiers[i].description, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(Money.formatPrice(tiers[i].priceCents), style: AppTextStyles.price),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
