import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// Opens a sheet for typing the 8 digits of a booking ID. Returns the digits,
/// or null when the sheet is dismissed.
Future<String?> showBookingIdSheet(BuildContext context, {String? demoDigits}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => BookingIdSheet(demoDigits: demoDigits),
  );
}

class BookingIdSheet extends StatefulWidget {
  const BookingIdSheet({super.key, this.demoDigits});

  /// A booking ID that works, shown as a hint in demo mode.
  final String? demoDigits;

  @override
  State<BookingIdSheet> createState() => _BookingIdSheetState();
}

class _BookingIdSheetState extends State<BookingIdSheet> {
  static const _length = 8;

  String _digits = '';

  bool get _complete => _digits.length == _length;

  void _submit() {
    if (_complete) Navigator.of(context).pop(_digits);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 20, AppSpacing.page, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter booking ID',
                style: AppTextStyles.screenTitle.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 4),
              const Text(
                "It is printed under the QR on the guest's e-ticket.",
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 14),
              AppTextField(
                autofocus: true,
                prefixText: 'TK',
                hintText: '48213377',
                letterSpacing: 1,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                onChanged: (value) => setState(() => _digits = value),
              ),
              if (widget.demoDigits != null) ...[
                const SizedBox(height: 8),
                Text('Demo: try ${widget.demoDigits}', style: AppTextStyles.caption),
              ],
              const SizedBox(height: 14),
              AppButton(
                label: 'Check ticket',
                height: 50,
                active: _complete,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
