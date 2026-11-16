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
import '../bloc/create_trip_bloc.dart';
import '../organisms/cover_photo_field.dart';

/// A bus company's form for publishing a trip: a tour to a province, with its
/// route, date, coach and price per seat. Expects a [CreateTripBloc] above it.
class CreateTripPage extends StatelessWidget {
  const CreateTripPage({super.key, this.commissionRateLabel = '5%'});

  /// Shown in the note about Pin's commission.
  final String commissionRateLabel;

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final bloc = context.read<CreateTripBloc>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      // A trip cannot be dated in the past.
      firstDate: today,
      lastDate: DateTime(today.year + 3, today.month, today.day),
    );
    if (picked != null) bloc.add(CreateTripDateChanged(picked));
  }

  Future<void> _pickTime(BuildContext context, CreateTripState state) async {
    final bloc = context.read<CreateTripBloc>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.hour ?? 8, minute: state.minute ?? 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      bloc.add(CreateTripTimeChanged(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateTripBloc, CreateTripState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice || previous.status != current.status,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) AppToast.show(context, notice);
        if (state.status == CreateTripStatus.published) context.pop();
      },
      builder: (context, state) {
        final bloc = context.read<CreateTripBloc>();
        final date = state.date;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              ScreenHeader(title: 'Create trip', onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 20),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            label: 'From',
                            hintText: 'Phnom Penh',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (origin) => bloc.add(CreateTripOriginChanged(origin)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'To',
                            hintText: 'Siem Reap',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (place) => bloc.add(CreateTripDestinationChanged(place)),
                          ),
                          const SizedBox(height: 14),
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
                                  label: 'Leaves at',
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
                            label: 'Journey time (hours)',
                            hintText: '6',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}([.,]\d{0,2})?')),
                            ],
                            onChanged: (hours) => bloc.add(CreateTripDurationChanged(hours)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Coach', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 10),
                          ChipSelector<CoachType>(
                            options: CoachType.values,
                            selected: state.coach,
                            labelOf: (coach) => coach.label,
                            onChanged: (coach) => bloc.add(CreateTripCoachChanged(coach)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.coach.seats} seats. Passengers choose their seat in the Pin app.',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Price per seat (USD)',
                            hintText: '0 for free',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,2})?')),
                            ],
                            onChanged: (price) => bloc.add(CreateTripPriceChanged(price)),
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
                            label: 'Boarding point',
                            hintText: 'Giant Ibis Terminal',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (point) => bloc.add(CreateTripBoardingPointChanged(point)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Street address · optional',
                            hintText: 'St 106, Riverside, Phnom Penh',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (address) =>
                                bloc.add(CreateTripBoardingAddressChanged(address)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('On board', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final amenity in CreateTripState.amenityOptions)
                                SelectableChip(
                                  label: amenity,
                                  selected: state.amenities.contains(amenity),
                                  onTap: () => bloc.add(CreateTripAmenityToggled(amenity)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'About the trip · optional',
                            hintText: 'Two days at Angkor, with a hotel night in Siem Reap',
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 3,
                            maxLines: 6,
                            onChanged: (about) => bloc.add(CreateTripAboutChanged(about)),
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
                      what: 'trip',
                      photo: state.photo,
                      enabled: state.status == CreateTripStatus.editing,
                      onChoose: (source) => bloc.add(CreateTripPhotoRequested(source)),
                      onRemove: () => bloc.add(const CreateTripPhotoRemoved()),
                    ),
                  ],
                ),
              ),
              _PublishBar(
                seats: state.coach.seats,
                canPublish: state.isValid,
                publishing: state.status == CreateTripStatus.submitting,
                onPublish: () => bloc.add(const CreateTripSubmitted()),
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
                  label: 'Publish trip',
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
