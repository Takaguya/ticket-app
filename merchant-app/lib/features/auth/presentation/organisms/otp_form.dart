import 'package:flutter/widgets.dart';

import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/molecules/otp_code_input.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// The 6-digit code boxes with the "Verify" button and the resend link.
class OtpForm extends StatelessWidget {
  const OtpForm({
    super.key,
    required this.phoneDisplay,
    required this.code,
    required this.canSubmit,
    required this.isVerifying,
    required this.secondsUntilResend,
    required this.onCodeChanged,
    required this.onSubmitted,
    required this.onResend,
    this.errorMessage,
    this.hint,
  });

  /// The number the code was sent to, formatted for reading.
  final String phoneDisplay;
  final String code;
  final bool canSubmit;
  final bool isVerifying;
  final int secondsUntilResend;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onResend;
  final String? errorMessage;

  /// Extra line under the resend link, e.g. the code to use in demo mode.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final waiting = secondsUntilResend > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enter the 6-digit code', style: AppTextStyles.headline),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'Sent by SMS to ',
            children: [
              TextSpan(
                text: phoneDisplay,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 26),
        OtpCodeInput(code: code, hasError: errorMessage != null, onChanged: onCodeChanged),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(errorMessage!, style: AppTextStyles.error),
        ],
        const SizedBox(height: 22),
        AppButton(
          label: 'Verify',
          shape: AppButtonShape.pill,
          active: canSubmit,
          loading: isVerifying,
          onPressed: onSubmitted,
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          enabled: !waiting,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: waiting ? null : onResend,
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
              alignment: Alignment.center,
              child: Text(
                waiting
                    ? 'Resend code in 0:${secondsUntilResend.toString().padLeft(2, '0')}'
                    : 'Resend code',
                style: AppTextStyles.link.copyWith(
                  color: waiting ? AppColors.textSubtle : AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}
