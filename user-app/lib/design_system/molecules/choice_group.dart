import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// One option of a [ChoiceGroup].
class Choice<T> {
  const Choice({required this.value, required this.label});

  final T value;
  final String label;
}

/// Equal-width buttons where at most one is chosen, e.g. Male / Female /
/// Other. Nothing is chosen until the person taps one.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  final List<Choice<T>> choices;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < choices.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _ChoiceButton(
              label: choices[i].label,
              selected: choices[i].value == selected,
              onTap: () => onChanged(choices[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.control);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.borderSoft,
            width: AppSizes.borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
