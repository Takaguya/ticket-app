import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/field_label.dart';
import '../tokens/app_colors.dart';

/// Form row: a small label, a borderless input and a divider underneath.
class LabeledTextField extends StatefulWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue = '',
    this.hintText,
    this.maxLength = 60,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.words,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final String? hintText;
  final int maxLength;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, color: AppColors.ink);

    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.label),
          TextField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
            style: style,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 8, bottom: 4),
              hintText: widget.hintText,
              hintStyle: style.copyWith(color: AppColors.placeholder),
            ),
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onSubmitted?.call(),
          ),
        ],
      ),
    );
  }
}
