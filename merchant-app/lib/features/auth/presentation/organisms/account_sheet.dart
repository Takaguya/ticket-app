import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/atoms/app_badge.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/initials_avatar.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/merchant_user.dart';
import '../bloc/auth/auth_bloc.dart';

/// Opens a bottom sheet with the signed-in person's details and "Sign out".
/// Available to owners and scanners alike.
Future<void> showAccountSheet(BuildContext context) {
  final authBloc = context.read<AuthBloc>();
  final user = authBloc.state.user;
  if (user == null) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetContext) => AccountSheet(
      user: user,
      onSignOut: () {
        Navigator.of(sheetContext).pop();
        authBloc.add(const AuthSignOutRequested());
      },
    ),
  );
}

/// Round button with the person's initials that opens the account sheet.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, this.onDark = false});

  /// Use on the dark scanner screen.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: 'Account',
      // Read as "Account", not as the initials inside.
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAccountSheet(context),
        child: SizedBox.square(
          dimension: AppSizes.tapTarget,
          child: Center(
            child: InitialsAvatar(
              initials: _initials(user.name),
              size: 34,
              backgroundColor: onDark ? AppColors.darkRaised : AppColors.primarySoft,
              foregroundColor: onDark ? AppColors.surface : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.user, required this.onSignOut});

  final MerchantUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialsAvatar(
                  initials: _initials(user.name),
                  size: 48,
                  backgroundColor: user.isOwner ? AppColors.accent : AppColors.primarySoft,
                  foregroundColor: user.isOwner ? AppColors.inkSoft : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: AppTextStyles.title.copyWith(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(PhoneNumber.display(user.phone), style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                AppBadge(label: user.role.label),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(user.businessName, style: AppTextStyles.bodyStrong),
            const SizedBox(height: 2),
            Text(
              user.isOwner
                  ? 'You own this business and can see everything.'
                  : 'You can scan tickets and see bookings.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign out',
              variant: AppButtonVariant.tonal,
              backgroundColor: AppColors.dangerSoft,
              foregroundColor: AppColors.danger,
              onPressed: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  return name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase())
      .take(2)
      .join();
}
