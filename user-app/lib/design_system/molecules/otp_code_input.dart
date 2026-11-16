import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/otp_cell.dart';
import '../tokens/app_dimens.dart';

/// Row of digit boxes for a one-time code.
///
/// A single invisible text field sits on top of the boxes and receives the
/// typing, so paste and SMS autofill work as they do in a normal field.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.code,
    required this.onChanged,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  /// The digits entered so far. The parent owns this value.
  final String code;
  final ValueChanged<String> onChanged;
  final int length;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.code);
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent can change the code, e.g. clear it after a wrong attempt.
    if (widget.code != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.code,
        selection: TextSelection.collapsed(offset: widget.code.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  OtpCellState _cellState(int index) {
    if (widget.hasError) return OtpCellState.error;
    if (index == math.min(widget.code.length, widget.length - 1)) return OtpCellState.active;
    if (index < widget.code.length) return OtpCellState.filled;
    return OtpCellState.empty;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OtpCell(
                    digit: i < widget.code.length ? widget.code[i] : '',
                    state: _cellState(i),
                  ),
                ),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: Semantics(
                label: 'Verification code',
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
