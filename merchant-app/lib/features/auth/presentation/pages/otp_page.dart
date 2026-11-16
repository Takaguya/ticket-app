import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/templates/auth_template.dart';
import '../../domain/entities/otp_verification.dart';
import '../bloc/otp/otp_bloc.dart';
import '../organisms/otp_form.dart';

/// Code entry screen. Expects an [OtpBloc] above it.
class OtpPage extends StatelessWidget {
  const OtpPage({super.key, this.hint});

  /// Extra line under the form, used in demo mode to show the code.
  final String? hint;

  void _onStateChanged(BuildContext context, OtpState state) {
    final notice = state.notice;
    if (notice != null) AppToast.show(context, notice);

    if (state.status != OtpStatus.verified) return;
    switch (state.verification) {
      case OtpRegistrationRequired(:final registrationToken, :final phone):
        // New number: register a business or join a team next.
        context.goNamed(
          AppRoutes.newAccount,
          extra: RegisterBusinessRouteArgs(registrationToken: registrationToken, phone: phone),
        );
      case OtpAuthenticated():
        // Signed in: the router sees the new session and opens the app.
        AppToast.show(context, 'Logged in');
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OtpBloc, OtpState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice || previous.status != current.status,
      listener: _onStateChanged,
      builder: (context, state) {
        final bloc = context.read<OtpBloc>();
        return AuthTemplate(
          onBack: () => context.pop(),
          body: OtpForm(
            phoneDisplay: PhoneNumber.display(state.phone),
            code: state.code,
            errorMessage: state.errorMessage,
            canSubmit: state.isCodeComplete,
            isVerifying: state.status == OtpStatus.verifying,
            secondsUntilResend: state.secondsLeft,
            hint: hint,
            onCodeChanged: (code) => bloc.add(OtpCodeChanged(code)),
            onSubmitted: () => bloc.add(const OtpSubmitted()),
            onResend: () => bloc.add(const OtpResendRequested()),
          ),
        );
      },
    );
  }
}
