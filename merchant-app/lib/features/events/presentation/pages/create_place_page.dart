import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../bloc/create_place_bloc.dart';
import '../organisms/cover_photo_field.dart';

/// An admission business's form for publishing a place that is open every
/// day: where it is, what it is about and its kinds of ticket, each with a
/// price and an optional limit per day. Expects a [CreatePlaceBloc] above it.
class CreatePlacePage extends StatelessWidget {
  const CreatePlacePage({super.key, this.commissionRateLabel = '5%'});

  /// Shown in the note about Pin's commission.
  final String commissionRateLabel;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreatePlaceBloc, CreatePlaceState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice || previous.status != current.status,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) AppToast.show(context, notice);
        if (state.status == CreatePlaceStatus.published) context.pop();
      },
      builder: (context, state) {
        final bloc = context.read<CreatePlaceBloc>();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              ScreenHeader(title: 'Create place', onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 20),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            label: 'Place',
                            hintText: 'Garden City Water Park',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (name) => bloc.add(CreatePlaceNameChanged(name)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Venue',
                            hintText: 'Garden City',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (venue) => bloc.add(CreatePlaceVenueChanged(venue)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Address · optional',
                            hintText: 'Chroy Changvar, Phnom Penh',
                            textCapitalization: TextCapitalization.words,
                            onChanged: (address) => bloc.add(CreatePlaceAddressChanged(address)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'About the place · optional',
                            hintText: 'Slides, a wave pool and a lazy river, open 08:00–17:00',
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 3,
                            maxLines: 6,
                            onChanged: (about) => bloc.add(CreatePlaceAboutChanged(about)),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Refund policy · optional',
                            hintText: 'Refundable up to the day before',
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (policy) => bloc.add(CreatePlacePolicyChanged(policy)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Ticket types', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 4),
                          const Text(
                            'The place is open every day. Visitors choose the day they come.',
                            style: AppTextStyles.caption,
                          ),
                          for (final ticket in state.tickets)
                            _TicketFields(
                              // The row keeps its text fields when another row is removed.
                              key: ValueKey(ticket.id),
                              row: ticket,
                              canRemove: state.tickets.length > 1,
                            ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Add ticket type',
                            icon: Icons.add_rounded,
                            variant: AppButtonVariant.outline,
                            height: 46,
                            onPressed: () => bloc.add(const CreatePlaceTicketAdded()),
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
                      what: 'place',
                      photo: state.photo,
                      enabled: state.status == CreatePlaceStatus.editing,
                      onChoose: (source) => bloc.add(CreatePlacePhotoRequested(source)),
                      onRemove: () => bloc.add(const CreatePlacePhotoRemoved()),
                    ),
                  ],
                ),
              ),
              _PublishBar(
                tickets: state.tickets.length,
                canPublish: state.isValid,
                publishing: state.status == CreatePlaceStatus.submitting,
                onPublish: () => bloc.add(const CreatePlaceSubmitted()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketFields extends StatelessWidget {
  const _TicketFields({super.key, required this.row, required this.canRemove});

  final PlaceTicketRow row;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CreatePlaceBloc>();

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
                  hintText: 'Ticket name, e.g. Adult',
                  initialValue: row.name,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (name) => bloc.add(CreatePlaceTicketChanged(row.id, name: name)),
                ),
              ),
              if (canRemove)
                SizedBox.square(
                  dimension: AppSizes.tapTarget,
                  child: IconButton(
                    onPressed: () => bloc.add(CreatePlaceTicketRemoved(row.id)),
                    padding: EdgeInsets.zero,
                    tooltip: 'Remove ticket type',
                    icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AppTextField(
            hintText: 'Who it is for, e.g. Under 12 · ID required',
            initialValue: row.description,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (text) => bloc.add(CreatePlaceTicketChanged(row.id, description: text)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Price (USD)',
                  hintText: '0 for free',
                  initialValue: row.price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,2})?')),
                  ],
                  onChanged: (price) => bloc.add(CreatePlaceTicketChanged(row.id, price: price)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  label: 'Max per day',
                  hintText: 'No limit',
                  initialValue: row.limit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  onChanged: (limit) => bloc.add(CreatePlaceTicketChanged(row.id, limit: limit)),
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
    required this.tickets,
    required this.canPublish,
    required this.publishing,
    required this.onPublish,
  });

  final int tickets;
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
                  const Text('Ticket types', style: AppTextStyles.caption),
                  Text('$tickets', style: AppTextStyles.title),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AppButton(
                  label: 'Publish place',
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
