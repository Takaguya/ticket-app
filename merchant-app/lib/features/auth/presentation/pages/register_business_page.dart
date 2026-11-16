import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/templates/auth_template.dart';
import '../bloc/register_business/register_business_bloc.dart';
import '../organisms/register_business_form.dart';

/// Step 2 of registration. Expects a [RegisterBusinessBloc] above it.
class RegisterBusinessPage extends StatelessWidget {
  const RegisterBusinessPage({super.key, required this.phone});

  /// The confirmed number in E.164 form.
  final String phone;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBusinessBloc, RegisterBusinessState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case RegisterBusinessStatus.failure:
            AppToast.show(context, state.errorMessage ?? 'Something went wrong');
          case RegisterBusinessStatus.success:
            // The router sees the new session and opens the app.
            AppToast.show(context, 'Account created. Welcome to Pin Merchant.');
          case RegisterBusinessStatus.editing || RegisterBusinessStatus.submitting:
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<RegisterBusinessBloc>();
        return AuthTemplate(
          onBack: () => context.pop(),
          body: RegisterBusinessForm(
            phoneDisplay: PhoneNumber.display(phone),
            type: state.type,
            onBusinessNameChanged: (name) => bloc.add(RegisterBusinessNameChanged(name)),
            onContactNameChanged: (name) => bloc.add(RegisterContactNameChanged(name)),
            onTypeChanged: (type) => bloc.add(RegisterBusinessTypeChanged(type)),
          ),
          footer: AppButton(
            label: 'Create account',
            shape: AppButtonShape.pill,
            active: state.isValid,
            loading: state.isSubmitting,
            onPressed: () => bloc.add(const RegisterBusinessSubmitted()),
          ),
        );
      },
    );
  }
}
