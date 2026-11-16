import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/media/photo_picker.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// The "Cover picture · optional" card of the Create forms: a preview of the photo
/// the owner chose (or a "No picture yet" tile) with "Gallery", "Camera" and
/// "Remove". The photo is uploaded when the event is published.
class CoverPhotoField extends StatelessWidget {
  const CoverPhotoField({
    super.key,
    required this.photo,
    required this.onChoose,
    required this.onRemove,
    this.enabled = true,
    this.what = 'event',
  });

  /// The chosen photo, or null for none.
  final Uint8List? photo;
  final ValueChanged<PhotoSource> onChoose;
  final VoidCallback onRemove;

  /// False while the form is being published.
  final bool enabled;

  /// What the picture is for, in the hint: "event", "trip", "screening" or "place".
  final String what;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cover picture · optional', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          Text('Buyers see it on the $what’s card and ticket in the Pin app.', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: photo == null
                  ? const _NoPicture()
                  : Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 900),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: photo == null ? 'Gallery' : 'Change',
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.outline,
                  height: 46,
                  onPressed: enabled ? () => onChoose(PhotoSource.gallery) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Camera',
                  icon: Icons.photo_camera_outlined,
                  variant: AppButtonVariant.outline,
                  height: 46,
                  onPressed: enabled ? () => onChoose(PhotoSource.camera) : null,
                ),
              ),
            ],
          ),
          if (photo != null)
            AppButton(
              label: 'Remove picture',
              variant: AppButtonVariant.text,
              foregroundColor: AppColors.danger,
              height: 44,
              onPressed: enabled ? onRemove : null,
            ),
        ],
      ),
    );
  }
}

class _NoPicture extends StatelessWidget {
  const _NoPicture();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.fill,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 34, color: AppColors.placeholder),
            SizedBox(height: 4),
            Text('No picture yet', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
