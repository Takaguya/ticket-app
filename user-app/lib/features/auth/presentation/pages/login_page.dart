import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/templates/auth_template.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../bloc/login/login_bloc.dart';
import '../organisms/login_form.dart';

/// First screen for signed-out people. Expects a [LoginBloc] above it.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case LoginStatus.failure:
            AppToast.show(context, state.errorMessage ?? 'Something went wrong');
          case LoginStatus.codeSent:
            context.goNamed(
              AppRoutes.otp,
              extra: OtpRouteArgs(phone: state.e164Phone, purpose: state.mode),
            );
          case LoginStatus.idle || LoginStatus.submitting:
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<LoginBloc>();
        return AuthTemplate(
          centerBody: true,
          body: LoginForm(
            mode: state.mode,
            canSubmit: state.isPhoneValid,
            isSubmitting: state.isSubmitting,
            onModeChanged: (mode) => bloc.add(LoginModeChanged(mode)),
            onPhoneChanged: (phone) => bloc.add(LoginPhoneChanged(phone)),
            onSubmitted: () => bloc.add(const LoginSubmitted()),
          ),
          footer: Text(
            "By continuing you agree to Pin's Terms & Conditions and Privacy Policy.",
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        );
      },
    );
  }
}
