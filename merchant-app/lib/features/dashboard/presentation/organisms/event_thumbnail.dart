import 'package:flutter/material.dart';

import '../../../../design_system/molecules/cover_image.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../events/domain/entities/event.dart';

/// An event's cover image as a small square in a list, or [fallback] (its date
/// tile) when it has none. With [onEditPicture] (the owner's view) a small
/// camera mark sits on its corner and tapping it opens the picture sheet.
class EventThumbnail extends StatelessWidget {
  const EventThumbnail({
    super.key,
    required this.event,
    required this.fallback,
    this.size = 48,
    this.onEditPicture,
  });

  final Event event;
  final Widget fallback;
  final double size;
  final VoidCallback? onEditPicture;

  @override
  Widget build(BuildContext context) {
    final picture = CoverImage(
      url: event.imageUrl,
      width: size,
      height: size,
      radius: 10,
      fallback: fallback,
    );
    final onEdit = onEditPicture;
    if (onEdit == null) return picture;

    return Semantics(
      button: true,
      label: event.imageUrl == null ? 'Add a picture to ${event.name}' : 'Change the picture of ${event.name}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onEdit,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            picture,
            const Positioned(right: -5, bottom: -5, child: _CameraMark()),
          ],
        ),
      ),
    );
  }
}

class _CameraMark extends StatelessWidget {
  const _CameraMark();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: AppColors.surface, width: 2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.photo_camera_rounded, size: 11, color: AppColors.surface),
      ),
    );
  }
}
