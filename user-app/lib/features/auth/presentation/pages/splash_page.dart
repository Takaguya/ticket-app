import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_logo.dart';
import '../../../../design_system/tokens/app_colors.dart';

/// Shown for a moment at start-up while the saved session is read.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(child: AppLogo(height: 88)),
    );
  }
}
