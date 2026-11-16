import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/photo_picker.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/molecules/cover_image.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/event.dart';
import '../bloc/event_picture_cubit.dart';

/// Opens the sheet where the owner adds, changes or removes an event's cover
/// image. Buyers see it on the event's card, page and ticket in the Pin app.
/// Needs an [EventPictureCubitFactory] above [context] (the router provides it).
Future<void> showEventPictureSheet(BuildContext context, {required Event event}) {
  final createCubit = context.read<EventPictureCubitFactory>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BlocProvider(
      create: (_) => createCubit(event),
      child: EventPictureSheet(eventName: event.name),
    ),
  );
}

/// The picture of one event with "Choose from gallery", "Take a photo" and
/// "Remove picture". Needs an [EventPictureCubit] above it.
class EventPictureSheet extends StatelessWidget {
  const EventPictureSheet({super.key, required this.eventName});

  final String eventName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: BlocBuilder<EventPictureCubit, EventPictureState>(
          builder: (context, state) {
            final cubit = context.read<EventPictureCubit>();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Event picture', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 2),
                Text(eventName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverImage(
                        url: state.imageUrl,
                        radius: AppRadii.control,
                        fallback: const _NoPicture(),
                      ),
                      if (state.working)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppRadii.control),
                          ),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
                if (state.message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(state.message!, style: AppTextStyles.error),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: state.imageUrl == null ? 'Choose from gallery' : 'Choose another photo',
                  icon: Icons.photo_library_outlined,
                  height: 48,
                  loading: state.working,
                  onPressed: state.working ? null : () => cubit.choose(PhotoSource.gallery),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'Take a photo',
                  icon: Icons.photo_camera_outlined,
                  variant: AppButtonVariant.outline,
                  height: 48,
                  onPressed: state.working ? null : () => cubit.choose(PhotoSource.camera),
                ),
                if (state.imageUrl != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  AppButton(
                    label: 'Remove picture',
                    variant: AppButtonVariant.text,
                    foregroundColor: AppColors.danger,
                    height: 44,
                    onPressed: state.working ? null : cubit.remove,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'JPEG or PNG, up to 5 MB. Buyers see it on the event’s card and ticket in the Pin app.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoPicture extends StatelessWidget {
  const _NoPicture();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 36, color: AppColors.placeholder),
            SizedBox(height: 4),
            Text('No picture yet', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
