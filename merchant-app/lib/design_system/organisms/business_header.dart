import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/app_badge.dart';
import '../atoms/app_logo.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Blue bar at the top of the main screen: logo, business name, the signed-in
/// person's name and their role.
class BusinessHeader extends StatelessWidget {
  const BusinessHeader({
    super.key,
    required this.businessName,
    required this.userName,
    required this.roleLabel,
    this.onTap,
  });

  final String businessName;
  final String userName;
  final String roleLabel;

  /// Tapping the header, e.g. to open the account sheet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // White status bar icons on the blue background.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: GestureDetector(
           behavior: HitTestBehavior.opaque,
           onTap: onTap,
           child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: AppLogo(height: 30),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.surface),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppBadge(label: roleLabel),
              ],
            ),
           ),
          ),
        ),
      ),
    );
  }
}
