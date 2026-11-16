import 'package:flutter/widgets.dart';

import '../atoms/selectable_chip.dart';
import '../tokens/app_dimens.dart';

/// Wrapping row of chips where exactly one is selected.
class ChipSelector<T> extends StatelessWidget {
  const ChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in options)
          SelectableChip(
            label: labelOf(option),
            selected: option == selected,
            onTap: () => onChanged(option),
          ),
      ],
    );
  }
}
