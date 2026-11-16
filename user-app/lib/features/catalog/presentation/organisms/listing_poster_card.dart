import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/date_tile.dart';
import '../../../../design_system/atoms/picture_placeholder.dart';
import '../../../../design_system/molecules/remote_image.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/listing.dart';
import '../category_style.dart';
import '../listing_text.dart';

/// A listing as a poster card: the picture (with the date of an event, or a
/// film's rating, in the corner), the name, one more line and the price.
class ListingPosterCard extends StatelessWidget {
  const ListingPosterCard({
    super.key,
    required this.listing,
    required this.subtitle,
    required this.onTap,
    this.showTag = false,
  });

  final Listing listing;

  /// The line under the name, e.g. the date or the venue.
  final String subtitle;
  final VoidCallback onTap;

  /// Shows the category's tag next to the price.
  final bool showTag;

  @override
  Widget build(BuildContext context) {
    final category = listing.category;
    return Semantics(
      button: true,
      label: '${listing.name}, $subtitle, ${listing.fromPriceText}',
      excludeSemantics: true,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: listing is FilmListing ? 0.86 : 1.55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RemoteImage(
                    path: listing.imageUrl,
                    fallback: PicturePlaceholder(caption: listing.name, icon: listing.icon, color: category.color),
                  ),
                  Positioned(left: 8, top: 8, child: _corner()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(height: 1.25),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.fromPriceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.price.copyWith(fontSize: 14.5),
                        ),
                      ),
                      if (showTag) listing.tagBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corner() {
    return switch (listing) {
      EventListing(:final startsAt) => DateTile(
        month: DateFormat.month(startsAt),
        day: '${startsAt.day}',
      ),
      FilmListing(:final rating) => AppBadge(
        label: rating,
        backgroundColor: AppColors.cinemaSoft,
        foregroundColor: AppColors.cinema,
      ),
      AdmissionListing() || BusRoute() => const SizedBox.shrink(),
    };
  }
}
