import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/labeled_text_field.dart';
import '../../../../design_system/templates/auth_template.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../bloc/join_team/join_team_bloc.dart';

/// Joining a business as a scanner. Expects a [JoinTeamBloc] above it.
class JoinTeamPage extends StatelessWidget {
  const JoinTeamPage({super.key, required this.phone});

  /// The confirmed number in E.164 form.
  final String phone;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JoinTeamBloc, JoinTeamState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case JoinTeamStatus.failure:
            AppToast.show(context, state.errorMessage ?? 'Something went wrong');
          case JoinTeamStatus.success:
            // The router sees the new session and opens the app.
            AppToast.show(context, 'You joined the team');
          case JoinTeamStatus.editing || JoinTeamStatus.submitting:
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<JoinTeamBloc>();
        return AuthTemplate(
          onBack: () => context.pop(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Join a team', style: AppTextStyles.headline),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: 'Number confirmed: ',
                  children: [
                    TextSpan(
                      text: PhoneNumber.display(phone),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const TextSpan(
                      text: '. Enter your name and the join code from the Staff screen of the '
                          "owner's app.",
                    ),
                  ],
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 14),
              LabeledTextField(
                label: 'Your name',
                hintText: 'Dara Keo',
                autofillHints: const [AutofillHints.name],
                onChanged: (name) => bloc.add(JoinTeamNameChanged(name)),
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: 'Join code',
                hintText: '482 913',
                letterSpacing: 3,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9 ]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (code) => bloc.add(JoinTeamCodeChanged(code)),
              ),
            ],
          ),
          footer: AppButton(
            label: 'Join team',
            shape: AppButtonShape.pill,
            active: state.isValid,
            loading: state.isSubmitting,
            onPressed: () => bloc.add(const JoinTeamSubmitted()),
          ),
        );
      },
    );
  }
}
