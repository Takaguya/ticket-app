import 'package:flutter/widgets.dart';

import '../atoms/icon_tile.dart';
import '../tokens/app_text_styles.dart';

/// A tinted icon with a bold line and a grey line beside it, e.g. the date
/// and start time of an event, or its venue and address.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconTile(icon: icon, background: iconBackground, foreground: iconColor, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
