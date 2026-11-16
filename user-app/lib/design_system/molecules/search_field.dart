import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_dimens.dart';

/// Grey rounded search box.
///
/// With [onTap] it is a button that opens the search page; with [onChanged]
/// it takes typing.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hintText,
    this.onTap,
    this.onChanged,
    this.autofocus = false,
    this.leadingIcon = Icons.search_rounded,
  }) : assert(onTap != null || onChanged != null, 'Give onTap or onChanged');

  final String hintText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.input);
    const hintStyle = TextStyle(fontSize: 15, color: AppColors.placeholder);
    final field = Row(
      children: [
        Icon(leadingIcon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: onChanged == null
              ? Text(hintText, maxLines: 1, overflow: TextOverflow.ellipsis, style: hintStyle)
              : TextField(
                  autofocus: autofocus,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15, color: AppColors.ink),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: hintText,
                    hintStyle: hintStyle,
                  ),
                  onChanged: onChanged,
                ),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      label: onTap != null ? hintText : null,
      child: Material(
        color: AppColors.fill,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: AppSizes.tapTarget,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: field,
          ),
        ),
      ),
    );
  }
}
