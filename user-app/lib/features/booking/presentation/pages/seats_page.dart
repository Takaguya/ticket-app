import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/presentation/organisms/price_action_bar.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/entities/seat_map.dart';
import '../bloc/seat_selection/seat_selection_bloc.dart';
import '../booking_navigation.dart';
import '../organisms/seat_map_view.dart';

/// The seats of a bus or a screening, to choose from. Expects a
/// [SeatSelectionBloc] above it.
class SeatsPage extends StatelessWidget {
  const SeatsPage({super.key, this.sellsSnacks = true});

  /// Whether a film's seats lead to the snack step (the mock sells snacks, the
  /// Pin API does not) or straight to checkout.
  final bool sellsSnacks;

  static String _subtitle(BookingRequest request) {
    return switch (request) {
      BusRequest(:final departure) =>
        '${request.title} · ${departure.operatorName} · ${DateFormat.time(departure.departsAt)} · '
            '${DateFormat.weekday(departure.departsAt)} ${DateFormat.dayMonth(departure.departsAt)}',
      CinemaRequest(:final theatre, :final showtime) =>
        '${theatre.name} · ${showtime.hall} · ${DateFormat.time(showtime.startsAt)}',
      EventRequest() || AdmissionRequest() => request.title,
    };
  }

  void _continue(BuildContext context, SeatSelectionState state) {
    final chosen = state.chosen;
    if (chosen == null) {
      AppToast.show(context, 'Choose at least one seat');
    } else {
      context.continueWithSeats(chosen, sellsSnacks: sellsSnacks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SeatSelectionBloc, SeatSelectionState>(
      listenWhen: (previous, current) => current.notice != null && previous.notice != current.notice,
      listener: (context, state) => AppToast.show(context, state.notice!),
      builder: (context, state) {
        final bloc = context.read<SeatSelectionBloc>();
        final seatMap = state.seatMap;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: AppColors.surface,
                  child: ScreenHeader(
                    title: 'Choose seats',
                    subtitle: _subtitle(state.request),
                    onBack: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: switch (state.status) {
                    SeatSelectionStatus.loading => const MessageView.loading(),
                    SeatSelectionStatus.failure => MessageView(
                      icon: Icons.event_seat_outlined,
                      title: "Can't show the seats",
                      message: state.errorMessage,
                      actionLabel: 'Try again',
                      onAction: () => bloc.add(const SeatSelectionStarted()),
                    ),
                    SeatSelectionStatus.ready => ListView(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      children: [
                        _SeatType(seatMap: seatMap!),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
                          child: SeatMapView(
                            seatMap: seatMap,
                            isSelected: state.isSelected,
                            onSeatTapped: (seat) => bloc.add(SeatToggled(seat)),
                          ),
                        ),
                      ],
                    ),
                  },
                ),
              ],
            ),
          ),
          bottomNavigationBar: PriceActionBar(
            caption: state.selected.isEmpty
                ? 'Tap seats to choose them'
                : '${state.selected.length == 1 ? 'Seat' : 'Seats'} '
                      '${state.selected.map((seat) => seat.id).join(', ')}',
            price: Money.format(state.totalCents),
            actionLabel: 'Continue',
            actionActive: state.selected.isNotEmpty,
            onAction: () => _continue(context, state),
          ),
        );
      },
    );
  }
}

/// The kind of seat or the hall, and the price of one seat.
class _SeatType extends StatelessWidget {
  const _SeatType({required this.seatMap});

  final SeatMap seatMap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          IconTile(
            icon: seatMap.hasScreen ? Icons.theaters_outlined : Icons.event_seat_outlined,
            background: AppColors.fill,
            foreground: AppColors.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seatMap.hasScreen ? 'HALL' : 'SEAT TYPE', style: AppTextStyles.fieldLabel),
                Text(seatMap.seatType, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('PER SEAT', style: AppTextStyles.fieldLabel),
              Text(Money.format(seatMap.priceCents), style: AppTextStyles.price),
            ],
          ),
        ],
      ),
    );
  }
}
