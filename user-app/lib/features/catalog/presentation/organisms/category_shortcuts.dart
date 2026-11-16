import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../domain/entities/available_categories.dart';
import '../../domain/entities/ticket_category.dart';
import '../category_style.dart';

/// The four round category buttons at the top of the Tickets page. A category
/// that is not on sale yet carries a "Soon" tag and calls [onComingSoon]
/// instead of [onSelected].
class CategoryShortcuts extends StatelessWidget {
  const CategoryShortcuts({
    super.key,
    required this.onSelected,
    required this.onComingSoon,
    this.available = AvailableCategories.all,
  });

  final ValueChanged<TicketCategory> onSelected;

  /// Tapped a category that is not on sale yet.
  final ValueChanged<TicketCategory> onComingSoon;
  final AvailableCategories available;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final category in TicketCategory.values)
          Expanded(
            child: Semantics(
              button: true,
              label: available.isOnSale(category) ? category.title : '${category.title}, coming soon',
              excludeSemantics: true,
              child: InkResponse(
                onTap: () => available.isOnSale(category) ? onSelected(category) : onComingSoon(category),
                radius: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconTile(
                            icon: category.icon,
                            background: category.softColor,
                            foreground: category.color,
                            size: 56,
                            shape: IconTileShape.circle,
                          ),
                          if (!available.isOnSale(category))
                            const Positioned(right: -10, top: -6, child: AppBadge(label: 'Soon')),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
