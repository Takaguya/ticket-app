import 'package:flutter/material.dart';

import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/field_label.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/molecules/choice_group.dart';
import '../../../../design_system/molecules/phone_number_field.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../auth/domain/entities/gender.dart';
import '../../domain/entities/runner_details.dart';
import '../bloc/runner_details/runner_details_bloc.dart';

/// The runner's details for a race: who runs (the person or someone else),
/// name, gender, age, nationality, phone, email, T-shirt size and an
/// emergency contact, and whether to keep them for the next race.
class RunnerForm extends StatelessWidget {
  const RunnerForm({
    super.key,
    required this.state,
    required this.onForSomeoneElseChanged,
    required this.onTextChanged,
    required this.onGenderChosen,
    required this.onShirtSizeChosen,
    required this.onSaveChanged,
  });

  final RunnerDetailsState state;
  final ValueChanged<bool> onForSomeoneElseChanged;
  final void Function(RunnerField field, String value) onTextChanged;
  final ValueChanged<Gender> onGenderChosen;
  final ValueChanged<ShirtSize> onShirtSizeChosen;
  final ValueChanged<bool> onSaveChanged;

  String get _hint {
    if (state.forSomeoneElse) {
      return "Enter the runner's details as they appear on their ID.";
    }
    return state.filledFromSaved
        ? 'Filled from your account and the details you saved last time.'
        : 'Filled from your account. Add the rest for the race kit.';
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup<bool>(
          choices: const [
            Choice(value: false, label: 'Myself'),
            Choice(value: true, label: 'Someone else'),
          ],
          selected: state.forSomeoneElse,
          onChanged: onForSomeoneElseChanged,
        ),
        const SizedBox(height: 10),
        Text(_hint, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        // Recreated whenever the bloc refills the form, so the fields show
        // the new values.
        KeyedSubtree(
          key: ValueKey(state.formVersion),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _text('Full name', RunnerField.name, state.name, hint: 'As on their ID', words: true),
                    gap,
                    const FieldLabel('Gender'),
                    const SizedBox(height: 8),
                    ChoiceGroup<Gender>(
                      choices: [for (final g in Gender.values) Choice(value: g, label: g.label)],
                      selected: state.gender,
                      onChanged: onGenderChosen,
                    ),
                    gap,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: _text(
                            'Age',
                            RunnerField.age,
                            state.age,
                            hint: '28',
                            keyboard: TextInputType.number,
                            maxLength: 2,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _text(
                            'Nationality',
                            RunnerField.nationality,
                            state.nationality,
                            hint: 'Cambodian',
                            words: true,
                          ),
                        ),
                      ],
                    ),
                    gap,
                    const FieldLabel('Phone number'),
                    const SizedBox(height: 8),
                    PhoneNumberField(
                      initialValue: state.phone,
                      onChanged: (value) => onTextChanged(RunnerField.phone, value),
                    ),
                    gap,
                    _text(
                      'Email · optional',
                      RunnerField.email,
                      state.email,
                      hint: 'For a copy of the e-ticket',
                      keyboard: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Race kit T-shirt size', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 10),
                    ChoiceGroup<ShirtSize>(
                      choices: [for (final s in ShirtSize.values) Choice(value: s, label: s.label)],
                      selected: state.shirtSize,
                      onChanged: onShirtSizeChosen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Emergency contact', style: AppTextStyles.sectionTitle),
                    const Text(
                      'Someone we can call if something happens on the course.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _text('Name', RunnerField.emergencyName, state.emergencyName, words: true),
                    gap,
                    const FieldLabel('Phone number'),
                    const SizedBox(height: 8),
                    PhoneNumberField(
                      initialValue: state.emergencyPhone,
                      onChanged: (value) => onTextChanged(RunnerField.emergencyPhone, value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: SwitchListTile(
            value: state.savesToAccount,
            onChanged: state.forSomeoneElse ? null : onSaveChanged,
            activeThumbColor: AppColors.surface,
            activeTrackColor: AppColors.success,
            title: const Text('Save to my account', style: AppTextStyles.bodyStrong),
            subtitle: Text(
              state.forSomeoneElse
                  ? 'Off when registering someone else'
                  : 'Reuse these details at your next race',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _text(
    String label,
    RunnerField field,
    String value, {
    String? hint,
    bool words = false,
    TextInputType keyboard = TextInputType.text,
    int maxLength = 80,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label),
        const SizedBox(height: 8),
        AppTextField(
          initialValue: value,
          hintText: hint,
          keyboardType: keyboard,
          textCapitalization: words ? TextCapitalization.words : TextCapitalization.none,
          maxLength: maxLength,
          onChanged: (text) => onTextChanged(field, text),
        ),
      ],
    );
  }
}
