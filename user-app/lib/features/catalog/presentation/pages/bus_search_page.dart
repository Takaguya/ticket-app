import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../booking/domain/entities/booking_request.dart';
import '../../../booking/presentation/booking_navigation.dart';
import '../bloc/bus_search/bus_search_bloc.dart';
import '../organisms/departure_card.dart';

/// "Bus tickets": where from, where to, which day, and the buses that go.
/// Expects a [BusSearchBloc] above it.
class BusSearchPage extends StatelessWidget {
  const BusSearchPage({super.key});

  /// How far ahead a bus can be booked.
  static const bookingWindowDays = 60;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: AppColors.surface,
              child: ScreenHeader(title: 'Bus tickets', onBack: () => context.pop()),
            ),
            Expanded(
              child: BlocBuilder<BusSearchBloc, BusSearchState>(
                builder: (context, state) => switch (state.status) {
                  BusSearchStatus.loading => const MessageView.loading(),
                  BusSearchStatus.failure => MessageView(
                    icon: Icons.wifi_off_rounded,
                    title: "Can't load bus routes",
                    message: state.errorMessage,
                    actionLabel: 'Try again',
                    onAction: () => context.read<BusSearchBloc>().add(const BusSearchStarted()),
                  ),
                  BusSearchStatus.ready => _Results(state: state),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state});

  final BusSearchState state;

  @override
  Widget build(BuildContext context) {
    final date = state.date!;
    final today = state.today!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        _SearchCard(state: state),
        const SizedBox(height: AppSpacing.md),
        ...switch (state.departuresStatus) {
          DeparturesStatus.loading => [const SizedBox(height: 120, child: MessageView.loading())],
          DeparturesStatus.failure => [
            MessageView(
              icon: Icons.wifi_off_rounded,
              title: "Can't find buses",
              message: state.errorMessage,
              actionLabel: 'Try again',
              onAction: () => context.read<BusSearchBloc>().add(BusDateChosen(date)),
            ),
          ],
          DeparturesStatus.loaded when state.departures.isEmpty => [
            MessageView(
              icon: Icons.directions_bus_outlined,
              title: 'No buses on this day',
              message: DateFormat.dateOnly(date) == today
                  ? "Today's buses have left. Try tomorrow."
                  : 'Try another day or another route.',
            ),
          ],
          DeparturesStatus.loaded => [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${state.departures.length} '
                '${state.departures.length == 1 ? 'departure' : 'departures'} · '
                '${DateFormat.relativeDay(date, today: today)}'
                    .toUpperCase(),
                style: AppTextStyles.fieldLabel.copyWith(fontSize: 12),
              ),
            ),
            for (final departure in state.departures)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: DepartureCard(
                  departure: departure,
                  onTap: () => context.chooseSeats(BusRequest(departure: departure)),
                ),
              ),
          ],
        },
      ],
    );
  }
}

/// From, swap, To, and the departure day.
class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.state});

  final BusSearchState state;

  Future<void> _pickPlace(BuildContext context, {required bool origin}) async {
    final bloc = context.read<BusSearchBloc>();
    final current = origin ? state.origin : state.destination;
    final place = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 8),
              child: Text(origin ? 'Leaving from' : 'Going to', style: AppTextStyles.title),
            ),
            for (final stop in state.stops)
              ListTile(
                title: Text(stop, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15.5)),
                trailing: stop == current
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(stop),
              ),
          ],
        ),
      ),
    );
    if (place == null) return;
    bloc.add(origin ? BusOriginChosen(place) : BusDestinationChosen(place));
  }

  Future<void> _pickDate(BuildContext context) async {
    final bloc = context.read<BusSearchBloc>();
    final today = state.today!;
    final picked = await showDatePicker(
      context: context,
      initialDate: state.date,
      firstDate: today,
      lastDate: today.add(const Duration(days: BusSearchPage.bookingWindowDays)),
      helpText: 'Departure',
    );
    if (picked != null) bloc.add(BusDateChosen(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Place(
                  label: 'From',
                  place: state.origin,
                  onTap: () => _pickPlace(context, origin: true),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Swap from and to',
                style: IconButton.styleFrom(backgroundColor: AppColors.fill),
                onPressed: () => context.read<BusSearchBloc>().add(const BusDirectionSwapped()),
                icon: const Icon(Icons.swap_vert_rounded, color: AppColors.ink),
              ),
              Expanded(
                child: _Place(
                  label: 'To',
                  place: state.destination,
                  alignEnd: true,
                  onTap: () => _pickPlace(context, origin: false),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.divider),
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => _pickDate(context),
              borderRadius: BorderRadius.circular(AppRadii.input),
              child: Row(
                children: [
                  const IconTile(
                    icon: Icons.calendar_month_outlined,
                    background: AppColors.warningSoft,
                    foreground: AppColors.warning,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEPARTURE', style: AppTextStyles.fieldLabel.copyWith(fontSize: 11)),
                        Text(
                          DateFormat.relativeDay(state.date!, today: state.today!),
                          style: AppTextStyles.bodyStrong.copyWith(fontSize: 15.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.placeholder),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({
    required this.label,
    required this.place,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final String place;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $place',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppTextStyles.fieldLabel.copyWith(fontSize: 11)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
