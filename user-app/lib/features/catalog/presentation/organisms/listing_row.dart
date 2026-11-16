import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/date_tile.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/listing.dart';
import '../category_style.dart';
import '../listing_text.dart';

/// A listing as a row: the event's date (or the category's icon), the name,
/// one more line and the price.
class ListingRow extends StatelessWidget {
  const ListingRow({
    super.key,
    required this.listing,
    required this.subtitle,
    required this.onTap,
    this.showTag = false,
  });

  final Listing listing;
  final String subtitle;
  final VoidCallback onTap;

  /// Shows the category's tag above the name.
  final bool showTag;

  @override
  Widget build(BuildContext context) {
    final category = listing.category;
    final leading = switch (listing) {
      EventListing(:final startsAt) => DecoratedBox(
        decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(9)),
        child: DateTile(month: DateFormat.month(startsAt), day: '${startsAt.day}'),
      ),
      _ => IconTile(
        icon: category.icon,
        background: category.softColor,
        foreground: category.color,
        size: 42,
      ),
    };

    return Semantics(
      button: true,
      label: '${listing.name}, $subtitle, ${listing.fromPriceText}',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTag) ...[listing.tagBadge(), const SizedBox(height: 4)],
                  Text(
                    listing.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(listing.fromPriceText, style: AppTextStyles.price.copyWith(fontSize: 13.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.placeholder),
          ],
        ),
      ),
    );
  }
}
