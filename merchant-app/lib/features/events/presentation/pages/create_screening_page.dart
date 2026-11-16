import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/selectable_chip.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/chip_selector.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/event.dart';
import '../bloc/create_screening_bloc.dart';
import '../organisms/cover_photo_field.dart';

/// A cinema's form for publishing one screening: the film, where and when it
/// shows, the hall's size and the price per seat. Expects a
/// [CreateScreeningBloc] above it.
class CreateScreeningPage extends StatelessWidget {
  const CreateScreeningPage({super.key, this.commissionRateLabel = '5%'});

  /// Shown in the note about Pin's commission.
  final String commissionRateLabel;

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final bloc = context.read<CreateScreeningBloc>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      // A screening cannot be dated in the past.
      firstDate: today,
      lastDate: DateTime(today.year + 3, today.month, today.day),
    );
    if (picked != null) bloc.add(CreateScreeningDateChanged(picked));
  }

  Future<void> _pickTime(BuildContext context, CreateScreeningState state) async {
    final bloc = context.read<CreateScreeningBloc>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.hour ?? 19, minute: state.minute ?? 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      bloc.add(CreateScreeningTimeChanged(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateScreeningBloc, CreateScreeningState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice || previous.status != current.status,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) AppToast.show(context, notice);
        if (state.status == CreateScreeningStatus.published) context.pop();
      },
      builder: (context, state) {
        final bloc = context.read<CreateScreeningBloc>();
        final date = state.date;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              ScreenHeader(title: 'Create screening', onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 20),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            label: 'Film',
                            hintText: 'Skyline Run',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (title) => bloc.add(CreateScreeningFilmChanged(title)),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Runs (minutes)',
                                  hintText: '112',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  onChanged: (minutes) =>
                                      bloc.add(CreateScreeningRuntimeChanged(minutes)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppTextField(
                                  label: 'Genre · optional',
                                  hintText: 'Action',
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: (genre) =>
                                      bloc.add(CreateScreeningGenreChanged(genre)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text('Rating · optional', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final rating in CreateScreeningState.ratingOptions)
                                SelectableChip(
                                  label: rating,
                                  selected: state.rating == rating,
                                  onTap: () => bloc.add(CreateScreeningRatingChosen(rating)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'About the film · optional',
                            hintText: 'A courier has 90 minutes to cross a locked-down city',
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 3,
                            maxLines: 6,
                            onChanged: (about) => bloc.add(CreateScreeningAboutChanged(about)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            label: 'Cinema',
                            hintText: 'Legend Cinema, Aeon Mall',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (theatre) =>
                                bloc.add(CreateScreeningTheatreChanged(theatre)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Address · optional',
                            hintText: 'Aeon Mall, Sihanouk Blvd, Phnom Penh',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (area) => bloc.add(CreateScreeningAreaChanged(area)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Hall',
                            hintText: 'Hall 3',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (hall) => bloc.add(CreateScreeningHallChanged(hall)),
                          ),
                          const SizedBox(height: 14),
                          const Text('Size of the hall', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 10),
                          ChipSelector<HallSize>(
                            options: HallSize.values,
                            selected: state.size,
                            labelOf: (size) => size.name,
                            onChanged: (size) => bloc.add(CreateScreeningSizeChanged(size)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.size.rows} rows of ${state.size.seatsPerRow}, '
                            '${state.size.seats} seats. Viewers choose their seat in the Pin app.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 13,
                                child: PickerField(
                                  label: 'Date',
                                  value: date == null ? null : DateFormat.full(date),
                                  placeholder: 'Choose',
                                  onTap: () => _pickDate(context, date),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 10,
                                child: PickerField(
                                  label: 'Starts at',
                                  value: state.hasTime
                                      ? DateFormat.time(DateTime(0, 1, 1, state.hour!, state.minute!))
                                      : null,
                                  placeholder: 'Choose',
                                  onTap: () => _pickTime(context, state),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Price per seat (USD)',
                            hintText: '0 for free',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,2})?')),
                            ],
                            onChanged: (price) => bloc.add(CreateScreeningPriceChanged(price)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Pin keeps $commissionRateLabel of every seat booked in the Pin app.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CoverPhotoField(
                      what: 'screening',
                      photo: state.photo,
                      enabled: state.status == CreateScreeningStatus.editing,
                      onChoose: (source) => bloc.add(CreateScreeningPhotoRequested(source)),
                      onRemove: () => bloc.add(const CreateScreeningPhotoRemoved()),
                    ),
                  ],
                ),
              ),
              _PublishBar(
                seats: state.size.seats,
                canPublish: state.isValid,
                publishing: state.status == CreateScreeningStatus.submitting,
                onPublish: () => bloc.add(const CreateScreeningSubmitted()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PublishBar extends StatelessWidget {
  const _PublishBar({
    required this.seats,
    required this.canPublish,
    required this.publishing,
    required this.onPublish,
  });

  final int seats;
  final bool canPublish;
  final bool publishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 14),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Seats', style: AppTextStyles.caption),
                  Text('$seats', style: AppTextStyles.title),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AppButton(
                  label: 'Publish screening',
                  active: canPublish,
                  loading: publishing,
                  onPressed: onPublish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
