import 'package:flutter/material.dart';

import '../atoms/app_back_button.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// White page header: an optional back arrow, the title (with an optional
/// line under it) and an optional action on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.onBack, this.trailing});

  final String title;

  /// A smaller line under the title, e.g. what is being booked.
  final String? subtitle;

  /// Shows the back arrow when set.
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        onBack == null ? AppSpacing.page : AppSpacing.page - 10,
        6,
        AppSpacing.page - 4,
        6,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            AppBackButton(onPressed: onBack!),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitle == null
                        ? AppTextStyles.title
                        : AppTextStyles.screenTitle.copyWith(fontSize: 19),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
