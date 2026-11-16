import 'package:flutter/widgets.dart';

import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_logo.dart';
import '../../../../design_system/atoms/field_label.dart';
import '../../../../design_system/molecules/phone_number_field.dart';
import '../../../../design_system/molecules/segmented_control.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/otp_verification.dart';

/// Logo, "Log in | Register" switch, phone number and the "Send code" button.
class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.mode,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onModeChanged,
    required this.onPhoneChanged,
    required this.onSubmitted,
  });

  final OtpPurpose mode;

  /// Whether the phone number looks complete. The button stays tappable
  /// either way so the screen can explain what is missing.
  final bool canSubmit;
  final bool isSubmitting;
  final ValueChanged<OtpPurpose> onModeChanged;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isRegister = mode == OtpPurpose.register;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: Alignment.centerLeft, child: AppLogo.wordmark(height: 58)),
        const SizedBox(height: 26),
        SegmentedControl<OtpPurpose>(
          options: const [
            SegmentOption(value: OtpPurpose.login, label: 'Log in'),
            SegmentOption(value: OtpPurpose.register, label: 'Register'),
          ],
          selected: mode,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 22),
        Text(
          isRegister ? 'Create your account' : 'Welcome back',
          style: AppTextStyles.display,
        ),
        const SizedBox(height: 6),
        Text(
          isRegister
              ? 'Enter your phone number. We will confirm it with a code, '
                    'then ask for a few details.'
              : 'Enter the phone number you registered with.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 26),
        const FieldLabel('Phone number'),
        const SizedBox(height: 8),
        PhoneNumberField(onChanged: onPhoneChanged, onSubmitted: onSubmitted),
        const SizedBox(height: 18),
        AppButton(
          label: 'Send code',
          active: canSubmit,
          loading: isSubmitting,
          onPressed: onSubmitted,
        ),
        const SizedBox(height: 14),
        const Text(
          'We will text you a 6-digit code to confirm your number.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
