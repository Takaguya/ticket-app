import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../../../../design_system/atoms/field_label.dart';
import '../../../../design_system/molecules/chip_selector.dart';
import '../../../../design_system/molecules/labeled_text_field.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/business_type.dart';

/// Step 2 of registration: business name, contact name and what they sell.
class RegisterBusinessForm extends StatelessWidget {
  const RegisterBusinessForm({
    super.key,
    required this.phoneDisplay,
    required this.type,
    required this.onBusinessNameChanged,
    required this.onContactNameChanged,
    required this.onTypeChanged,
  });

  /// The confirmed number, formatted for reading.
  final String phoneDisplay;
  final BusinessType type;
  final ValueChanged<String> onBusinessNameChanged;
  final ValueChanged<String> onContactNameChanged;
  final ValueChanged<BusinessType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'STEP 2 OF 2',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text('Tell us about your business', style: AppTextStyles.headline),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'Number confirmed: ',
            children: [
              TextSpan(
                text: phoneDisplay,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const TextSpan(
                text: '. You become the owner and can add scanners later with a join code.',
              ),
            ],
          ),
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 14),
        LabeledTextField(
          label: 'Business name',
          hintText: 'Khmer Runners Club',
          autofillHints: const [AutofillHints.organizationName],
          onChanged: onBusinessNameChanged,
        ),
        LabeledTextField(
          label: 'Your name',
          hintText: 'Vannak Sok',
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.done,
          onChanged: onContactNameChanged,
        ),
        const SizedBox(height: 14),
        const FieldLabel('What do you sell?'),
        const SizedBox(height: 8),
        ChipSelector<BusinessType>(
          options: BusinessType.values,
          selected: type,
          labelOf: (type) => type.label,
          onChanged: onTypeChanged,
        ),
      ],
    );
  }
}
