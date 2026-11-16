import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../atoms/app_back_button.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Page layout for the sign-in screens: an optional back arrow, a scrolling
/// body and an optional footer pinned to the bottom.
class AuthTemplate extends StatelessWidget {
  const AuthTemplate({
    super.key,
    required this.body,
    this.onBack,
    this.footer,
    this.centerBody = false,
  });

  final Widget body;

  /// Shows the back arrow when set.
  final VoidCallback? onBack;
  final Widget? footer;

  /// Centres the body vertically when it is shorter than the screen.
  final bool centerBody;

  static const double _bodyPaddingV = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onBack != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.pageWide - 10, top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppBackButton(onPressed: onBack!),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageWide,
                      vertical: _bodyPaddingV,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // Never negative, even when the keyboard leaves little room.
                        minHeight: math.max(0.0, constraints.maxHeight - _bodyPaddingV * 2),
                      ),
                      child: Align(
                        alignment: centerBody ? Alignment.center : Alignment.topCenter,
                        child: SizedBox(width: double.infinity, child: body),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageWide,
                  10,
                  AppSpacing.pageWide,
                  14,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
