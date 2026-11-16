import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/templates/auth_template.dart';
import '../bloc/register/register_bloc.dart';
import '../organisms/register_form.dart';

/// "Your details" after a new number is confirmed. Expects a [RegisterBloc]
/// above it.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key, required this.phone, this.clock = const Clock()});

  /// The confirmed number, E.164 form.
  final String phone;
  final Clock clock;

  Future<void> _pickDateOfBirth(BuildContext context, RegisterState state) async {
    final bloc = context.read<RegisterBloc>();
    final today = clock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.dateOfBirth ?? DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
    );
    if (picked != null) bloc.add(RegisterDateOfBirthChanged(picked));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, RegisterState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case RegisterStatus.failure:
            AppToast.show(context, state.errorMessage ?? 'Something went wrong');
          case RegisterStatus.registered:
            // Signed in: the router sees the new session and opens the app.
            AppToast.show(context, 'Welcome to Pin, ${state.firstName}');
          case RegisterStatus.idle || RegisterStatus.submitting:
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<RegisterBloc>();
        return AuthTemplate(
          // The code is used up: going back means starting again.
          onBack: () => context.goNamed(AppRoutes.login),
          body: RegisterForm(
            phoneDisplay: PhoneNumber.display(phone),
            gender: state.gender,
            dateOfBirth: state.dateOfBirth,
            canSubmit: state.canSubmit,
            isSubmitting: state.isSubmitting,
            onNameChanged: (name) => bloc.add(RegisterNameChanged(name)),
            onGenderChanged: (gender) => bloc.add(RegisterGenderChanged(gender)),
            onPickDateOfBirth: () => _pickDateOfBirth(context, state),
            onEmailChanged: (email) => bloc.add(RegisterEmailChanged(email)),
            onSubmitted: () => bloc.add(const RegisterSubmitted()),
          ),
        );
      },
    );
  }
}
