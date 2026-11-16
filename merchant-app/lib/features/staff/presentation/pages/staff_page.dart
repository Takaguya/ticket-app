import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/initials_avatar.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/list_row.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../auth/domain/entities/merchant_user.dart';
import '../../../auth/domain/entities/staff_role.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../dashboard/presentation/bloc/business/business_bloc.dart';
import '../../domain/entities/team.dart';
import '../bloc/staff_bloc.dart';

/// Owner's staff screen. Expects [StaffBloc], [BusinessBloc] and [AuthBloc]
/// above it.
class StaffPage extends StatelessWidget {
  const StaffPage({super.key, required this.user});

  final MerchantUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ScreenHeader(title: 'Staff'),
        Expanded(
          child: BlocConsumer<StaffBloc, StaffState>(
            listenWhen: (previous, current) => previous.notice != current.notice,
            listener: (context, state) {
              final notice = state.notice;
              if (notice != null) AppToast.show(context, notice);
            },
            builder: (context, state) {
              final team = state.team;
              return switch (state.status) {
                StaffStatus.loading => const MessageView.loading(),
                StaffStatus.ready when team != null => _StaffContent(team: team, user: user),
                _ => const MessageView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load your staff',
                  message: 'Check your connection and open the app again.',
                ),
              };
            },
          ),
        ),
      ],
    );
  }
}

class _StaffContent extends StatelessWidget {
  const _StaffContent({required this.team, required this.user});

  final Team team;
  final MerchantUser user;

  Future<void> _confirmRemove(BuildContext context, StaffMember member) async {
    final bloc = context.read<StaffBloc>();
    final confirmed = await _confirm(
      context,
      title: 'Remove ${member.name}?',
      message: 'They will no longer be able to scan tickets or see bookings.',
      action: 'Remove',
    );
    if (confirmed) bloc.add(StaffMemberRemoved(member));
  }

  Future<void> _confirmNewCode(BuildContext context) async {
    final bloc = context.read<StaffBloc>();
    final confirmed = await _confirm(
      context,
      title: 'Create a new join code?',
      message: 'The current code stops working. Scanners who already joined stay on the team.',
      action: 'New code',
    );
    if (confirmed) bloc.add(const StaffJoinCodeRenewed());
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select((BusinessBloc bloc) => bloc.state.snapshot);
    final live = snapshot?.liveEvent;
    final code = _spaced(team.joinCode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, AppSpacing.lg),
      children: [
        _JoinCodeCard(
          code: code,
          businessName: user.businessName,
          onShare: () async {
            await Clipboard.setData(ClipboardData(text: team.joinCode));
            if (context.mounted) AppToast.show(context, 'Join code copied');
          },
          onNewCode: () => _confirmNewCode(context),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (final (index, member) in team.members.indexed)
                _MemberRow(
                  member: member,
                  isCurrentUser: member.id == user.id,
                  scansToday: live == null ? 0 : snapshot!.scansBy(member.name, live.id),
                  showDivider: index < team.members.length - 1,
                  onRemove: () => _confirmRemove(context, member),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Sign out',
          height: 50,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.danger,
          onPressed: () => context.read<AuthBloc>().add(const AuthSignOutRequested()),
        ),
      ],
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({
    required this.code,
    required this.businessName,
    required this.onShare,
    required this.onNewCode,
  });

  final String code;
  final String businessName;
  final VoidCallback onShare;
  final VoidCallback onNewCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primary,
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join code for scanners',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.surface),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Join code ${code.split('').join(' ')}',
            excludeSemantics: true,
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: 5,
                height: 1.1,
                color: AppColors.surface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A scanner enters this code in Pin Merchant to join $businessName. Scanners can '
            'scan tickets and see bookings only.',
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.surface),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Share code',
                  height: 46,
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.inkSoft,
                  onPressed: onShare,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'New code',
                  height: 46,
                  variant: AppButtonVariant.outline,
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.surface,
                  onPressed: onNewCode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isCurrentUser,
    required this.scansToday,
    required this.showDivider,
    required this.onRemove,
  });

  final StaffMember member;
  final bool isCurrentUser;
  final int scansToday;
  final bool showDivider;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role == StaffRole.owner;

    return ListRow(
      minHeight: 68,
      showDivider: showDivider,
      leading: InitialsAvatar(
        initials: member.initials,
        backgroundColor: isOwner ? AppColors.accent : AppColors.primarySoft,
        foregroundColor: isOwner ? AppColors.inkSoft : AppColors.primary,
      ),
      title: isCurrentUser ? '${member.name} (you)' : member.name,
      subtitle:
          '${member.role.label} · $scansToday ${scansToday == 1 ? 'scan' : 'scans'} today',
      trailing: isOwner
          ? null
          : TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              child: const Text('Remove'),
            ),
    );
  }
}

/// `482913` -> `482 913`
String _spaced(String code) {
  return code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
