import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/initials_avatar.dart';
import '../../../../design_system/molecules/confirm_dialog.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../auth/domain/entities/pin_user.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';

/// The Profile tab: who is signed in, their details, and signing out.
/// Expects an [AuthBloc] above it.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user});

  final PinUser user;

  Future<void> _signOut(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to see your tickets.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (confirmed) authBloc.add(const AuthSignOutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ColoredBox(
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 18, AppSpacing.page, 18),
              child: Text(
                'Profile',
                style: AppTextStyles.headline.copyWith(color: AppColors.surface),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                elevated: true,
                child: Row(
                  children: [
                    InitialsAvatar(name: user.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: AppTextStyles.title.copyWith(fontSize: 18)),
                          Text(PhoneNumber.local(user.phone), style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    _Detail(label: 'Phone', value: PhoneNumber.display(user.phone)),
                    _Detail(label: 'Email', value: user.email ?? 'Not added'),
                    _Detail(label: 'Gender', value: user.gender.label),
                    _Detail(
                      label: 'Date of birth',
                      value: DateFormat.full(user.dateOfBirth),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                onTap: () => _signOut(context),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
