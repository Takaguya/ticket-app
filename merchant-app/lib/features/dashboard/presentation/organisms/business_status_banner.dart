import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../auth/domain/entities/business_status.dart';

/// Tells the team why nothing sells: Pin has not approved the business yet,
/// or has suspended it. Nothing is shown for an active business.
class BusinessStatusBanner extends StatelessWidget {
  const BusinessStatusBanner({super.key, required this.status});

  final BusinessStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message, background, foreground) = switch (status) {
      BusinessStatus.active => (null, '', '', AppColors.surface, AppColors.ink),
      BusinessStatus.pending => (
        Icons.hourglass_top_rounded,
        'Waiting for Pin’s approval',
        'You can set up events now. Tickets go on sale once Pin approves your business.',
        AppColors.warningSoft,
        AppColors.warning,
      ),
      BusinessStatus.suspended => (
        Icons.block_rounded,
        'Your business is suspended',
        'Pin has stopped ticket sales and new events. Tickets already sold can still be '
            'scanned. Contact Pin to sell again.',
        AppColors.dangerSoft,
        AppColors.danger,
      ),
    };
    if (icon == null) return const SizedBox.shrink();

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyStrong.copyWith(color: foreground)),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: AppTextStyles.bodySmall.copyWith(color: foreground, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
