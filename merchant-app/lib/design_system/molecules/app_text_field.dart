import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Label style shared by [AppTextField] and [PickerField].
const _labelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: AppColors.textMuted,
);
const _valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink);

/// Bordered text input with an optional label above it.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.onChanged,
    this.label,
    this.initialValue = '',
    this.hintText,
    this.prefixText,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.autofocus = false,
    this.letterSpacing,
    this.minLines = 1,
    this.maxLines = 1,
  });

  /// A longer text, e.g. a description: the field grows from [minLines] to
  /// [maxLines] lines.
  final int minLines;
  final int maxLines;

  final ValueChanged<String> onChanged;
  final String? label;
  final String initialValue;
  final String? hintText;

  /// Fixed text before the input, e.g. `TK`.
  final String? prefixText;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final double? letterSpacing;

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
    final style = _valueStyle.copyWith(letterSpacing: widget.letterSpacing);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: color, width: AppSizes.borderWidth),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: _labelStyle),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          style: style,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            hintText: widget.hintText,
            hintStyle: style.copyWith(color: AppColors.placeholder),
            prefixText: widget.prefixText == null ? null : '${widget.prefixText} ',
            prefixStyle: style.copyWith(color: AppColors.textMuted),
            enabledBorder: border(AppColors.border),
            focusedBorder: border(AppColors.primary),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

/// Looks like [AppTextField] but opens a picker (date, time) when tapped.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;

  /// The chosen value, or null when nothing is chosen yet.
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.input);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: const BorderSide(color: AppColors.border, width: AppSizes.borderWidth),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                height: 48,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: Text(
                  value ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: value == null
                      ? _valueStyle.copyWith(color: AppColors.placeholder)
                      : _valueStyle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
