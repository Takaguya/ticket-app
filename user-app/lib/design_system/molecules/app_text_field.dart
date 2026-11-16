import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';
import '../tokens/app_text_styles.dart';

/// Single-line text input in the sign-in style: a rounded box whose border
/// turns blue once something is typed.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.onChanged,
    this.hintText,
    this.initialValue = '',
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.maxLength,
    this.autofocus = false,
    this.onSubmitted,
  });

  final ValueChanged<String> onChanged;
  final String? hintText;
  final String initialValue;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
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
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(
              color: _controller.text.isEmpty ? AppColors.border : AppColors.primary,
              width: AppSizes.borderWidth,
            ),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: child,
        );
      },
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        maxLength: widget.maxLength,
        style: AppTextStyles.input,
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: widget.hintText,
          hintStyle: AppTextStyles.input.copyWith(color: AppColors.placeholder),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: widget.onChanged,
        onSubmitted: (_) => widget.onSubmitted?.call(),
      ),
    );
  }
}
