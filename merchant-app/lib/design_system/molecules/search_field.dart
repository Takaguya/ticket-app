import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Grey rounded search box with a clear button.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hintText,
  });

  /// The current query. The parent owns it.
  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent can change the query, e.g. reset it when switching event.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 15, color: Color(0xFF222222));

    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        color: AppColors.dividerSoft,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              style: style,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                hintText: widget.hintText,
                hintStyle: style.copyWith(color: AppColors.placeholder),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (widget.value.isEmpty)
            const SizedBox(width: 14)
          else
            SizedBox.square(
              dimension: AppSizes.tapTarget,
              child: IconButton(
                onPressed: _clear,
                padding: EdgeInsets.zero,
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
