import 'package:flutter/widgets.dart';

import '../tokens/app_text_styles.dart';

/// Small uppercase label shown above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppTextStyles.fieldLabel);
  }
}
