import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/phone_number.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// Phone input with a fixed +855 country code.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.onChanged,
    this.initialValue = '',
    this.onSubmitted,
    this.autofocus = false,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Container(
          constraints: const BoxConstraints(minHeight: AppSizes.fieldHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: _controller.text.isEmpty ? AppColors.border : AppColors.primary,
              width: AppSizes.borderWidth,
            ),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Text(
            PhoneNumber.countryCode,
            style: AppTextStyles.input.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 1, height: 22, child: ColoredBox(color: AppColors.border)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9 ]')),
                LengthLimitingTextInputFormatter(12),
              ],
              style: AppTextStyles.input,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '12 345 678',
                hintStyle: AppTextStyles.input.copyWith(color: AppColors.placeholder),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: widget.onChanged,
              onSubmitted: (_) => widget.onSubmitted?.call(),
            ),
          ),
        ],
      ),
    );
  }
}
