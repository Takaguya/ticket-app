import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/field_label.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/molecules/choice_group.dart';
import '../../../../design_system/molecules/date_field.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/gender.dart';

/// "Your details" for a new account: name, gender, date of birth and an
/// optional email, then "Create account".
class RegisterForm extends StatelessWidget {
  const RegisterForm({
    super.key,
    required this.phoneDisplay,
    required this.gender,
    required this.dateOfBirth,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onNameChanged,
    required this.onGenderChanged,
    required this.onPickDateOfBirth,
    required this.onEmailChanged,
    required this.onSubmitted,
  });

  /// The confirmed number, formatted for reading.
  final String phoneDisplay;
  final Gender? gender;
  final DateTime? dateOfBirth;
  final bool canSubmit;
  final bool isSubmitting;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<Gender> onGenderChanged;
  final VoidCallback onPickDateOfBirth;
  final ValueChanged<String> onEmailChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Your details', style: AppTextStyles.headline),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'Almost done. ',
            children: [
              TextSpan(
                text: phoneDisplay,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const TextSpan(text: ' is confirmed.'),
            ],
          ),
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 24),
        const FieldLabel('Full name'),
        const SizedBox(height: 8),
        AppTextField(
          hintText: 'Sokha Chan',
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          maxLength: 80,
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 18),
        const FieldLabel('Gender'),
        const SizedBox(height: 8),
        ChoiceGroup<Gender>(
          choices: [for (final g in Gender.values) Choice(value: g, label: g.label)],
          selected: gender,
          onChanged: onGenderChanged,
        ),
        const SizedBox(height: 18),
        const FieldLabel('Date of birth'),
        const SizedBox(height: 8),
        DateField(
          valueText: dateOfBirth == null ? null : DateFormat.full(dateOfBirth!),
          hintText: 'Choose a date',
          onTap: onPickDateOfBirth,
        ),
        const SizedBox(height: 18),
        const FieldLabel('Email · optional'),
        const SizedBox(height: 8),
        AppTextField(
          hintText: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          maxLength: 254,
          onChanged: onEmailChanged,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Create account',
          active: canSubmit,
          loading: isSubmitting,
          onPressed: onSubmitted,
        ),
      ],
    );
  }
}
