import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/templates/auth_template.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// Shown after a phone number without an account is confirmed: register a
/// new business, or join an existing one as a scanner.
class NewAccountPage extends StatelessWidget {
  const NewAccountPage({super.key, required this.args});

  final RegisterBusinessRouteArgs args;

  @override
  Widget build(BuildContext context) {
    return AuthTemplate(
      onBack: () => context.goNamed(AppRoutes.login),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Welcome to Pin Merchant', style: AppTextStyles.headline),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: 'Number confirmed: ',
              children: [
                TextSpan(
                  text: PhoneNumber.display(args.phone),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const TextSpan(text: '. How will you use the app?'),
              ],
            ),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 22),
          _ChoiceCard(
            icon: Icons.storefront_outlined,
            title: 'Register a business',
            description: 'Sell tickets, check guests in and follow your sales. You become the '
                'owner.',
            onTap: () => context.goNamed(AppRoutes.registerBusiness, extra: args),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Join a team with a code',
            description: 'Scan tickets at the entrance for a business. Ask the owner for the '
                '6-digit join code.',
            onTap: () => context.goNamed(AppRoutes.joinTeam, extra: args),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.card);

    return Semantics(
      button: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border, width: AppSizes.borderWidth),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.input),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(description, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
