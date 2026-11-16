import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/molecules/chip_selector.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/event.dart';
import '../bloc/create_event_bloc.dart';
import '../organisms/cover_photo_field.dart';

/// Owner's form for publishing an event. Expects a [CreateEventBloc] above it.
class CreateEventPage extends StatelessWidget {
  const CreateEventPage({super.key, this.commissionRateLabel = '5%'});

  /// Shown in the note about Pin's commission.
  final String commissionRateLabel;

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final bloc = context.read<CreateEventBloc>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      // An event cannot be dated in the past.
      firstDate: today,
      lastDate: DateTime(today.year + 3, today.month, today.day),
    );
    if (picked != null) bloc.add(CreateEventDateChanged(picked));
  }

  Future<void> _pickTime(BuildContext context, CreateEventState state) async {
    final bloc = context.read<CreateEventBloc>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.hour ?? 6, minute: state.minute ?? 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      bloc.add(CreateEventTimeChanged(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateEventBloc, CreateEventState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice || previous.status != current.status,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) AppToast.show(context, notice);
        if (state.status == CreateEventStatus.published) context.pop();
      },
      builder: (context, state) {
        final bloc = context.read<CreateEventBloc>();
        final date = state.date;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              ScreenHeader(title: 'Create event', onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 20),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            label: 'Event name',
                            hintText: 'Riverside Night Run',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (name) => bloc.add(CreateEventNameChanged(name)),
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
                                  label: 'Start time',
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
                            label: 'Venue',
                            hintText: 'Riverside, Sisowath Quay',
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onChanged: (venue) => bloc.add(CreateEventVenueChanged(venue)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('What kind of event?', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 10),
                          ChipSelector<EventKind?>(
                            options: EventKind.forEvents,
                            selected: state.kind,
                            labelOf: (kind) => kind!.label,
                            onChanged: (kind) => bloc.add(CreateEventKindChanged(kind!)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Marathon buyers are asked for the runner\'s details.',
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
                          const Text('Ticket types',style: AppTextStyles.sectionTitle),
                          for (final type in state.ticketTypes)
                            _TicketTypeFields(
                              // The row keeps its text fields when another row is removed.
                              key: ValueKey(type.id),
                              draft: type,
                              canRemove: state.ticketTypes.length > 1,
                            ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Add ticket type',
                            icon: Icons.add_rounded,
                            variant: AppButtonVariant.outline,
                            height: 46,
                            onPressed: () => bloc.add(const CreateEventTicketTypeAdded()),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Pin keeps $commissionRateLabel of every ticket booked in the Pin app.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CoverPhotoField(
                      what: 'event',
                      photo: state.photo,
                      enabled: state.status == CreateEventStatus.editing,
                      onChoose: (source) => bloc.add(CreateEventPhotoRequested(source)),
                      onRemove: () => bloc.add(const CreateEventPhotoRemoved()),
                    ),
                  ],
                ),
              ),
              _PublishBar(
                capacity: state.capacity,
                canPublish: state.isValid,
                publishing: state.status == CreateEventStatus.submitting,
                onPublish: () => bloc.add(const CreateEventSubmitted()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketTypeFields extends StatelessWidget {
  const _TicketTypeFields({super.key, required this.draft, required this.canRemove});

  final TicketTypeDraft draft;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CreateEventBloc>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dividerSoft)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  hintText: 'Ticket name, e.g. 10K',
                  initialValue: draft.name,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (name) =>
                      bloc.add(CreateEventTicketTypeChanged(draft.id, name: name)),
                ),
              ),
              if (canRemove)
                SizedBox.square(
                  dimension: AppSizes.tapTarget,
                  child: IconButton(
                    onPressed: () => bloc.add(CreateEventTicketTypeRemoved(draft.id)),
                    padding: EdgeInsets.zero,
                    tooltip: 'Remove ticket type',
                    icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Price (USD)',
                  hintText: '0 for free',
                  initialValue: draft.price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,2})?')),
                  ],
                  onChanged: (price) =>
                      bloc.add(CreateEventTicketTypeChanged(draft.id, price: price)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  label: 'Tickets for sale',
                  hintText: '200',
                  initialValue: draft.quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  onChanged: (quantity) =>
                      bloc.add(CreateEventTicketTypeChanged(draft.id, quantity: quantity)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublishBar extends StatelessWidget {
  const _PublishBar({
    required this.capacity,
    required this.canPublish,
    required this.publishing,
    required this.onPublish,
  });

  final int capacity;
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
                  const Text('Capacity', style: AppTextStyles.caption),
                  Text('$capacity', style: AppTextStyles.title),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AppButton(
                  label: 'Publish event',
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
