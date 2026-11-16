import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/picture_placeholder.dart';
import '../../../../design_system/molecules/remote_image.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/presentation/category_style.dart';
import '../../domain/entities/booking_request.dart';
import '../booking_text.dart';

/// What is being booked, at the top of checkout: a picture, the title, when
/// and where.
class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({super.key, required this.request});

  final BookingRequest request;

  @override
  Widget build(BuildContext context) {
    final category = request.category;
    return AppCard(
      child: Row(
        children: [
          SizedBox.square(
            dimension: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: RemoteImage(
                path: request.imageUrl,
                fallback: PicturePlaceholder(icon: request.icon, color: category.color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                request.tagBadge(),
                const SizedBox(height: 4),
                Text(request.title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(request.whenText, style: AppTextStyles.bodySmall),
                Text(request.place, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
