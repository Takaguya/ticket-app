import 'package:flutter/material.dart';

import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// A section's title with an optional "See all" link on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;

  /// Shows "See all ›" when set.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.tapTarget,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppTextStyles.title.copyWith(fontSize: 18)),
            ),
          ),
          if (onSeeAll != null)
            Semantics(
              button: true,
              label: 'See all $title',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeAll,
                child: const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm),
                  child: Center(child: Text('See all ›', style: AppTextStyles.link)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
