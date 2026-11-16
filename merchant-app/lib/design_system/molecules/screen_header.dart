import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/app_back_button.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// White bar at the top of a screen: optional back arrow, title, optional
/// subtitle and trailing widget, and optional extra rows underneath.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.bottom,
  });

  final String title;
  final String? subtitle;

  /// Shows the back arrow when set.
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Extra content inside the header, e.g. search and filters.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final hasBack = onBack != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              hasBack ? 2 : AppSpacing.page,
              hasBack ? 6 : 10,
              AppSpacing.page,
              hasBack ? 6 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
                  child: Row(
                    children: [
                      if (hasBack) AppBackButton(onPressed: onBack!),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: hasBack
                                  ? AppTextStyles.screenTitle.copyWith(fontSize: 17)
                                  : AppTextStyles.screenTitle,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                    ],
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
