import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/day_strip.dart';
import '../../../../design_system/molecules/quantity_row.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/domain/entities/listing.dart';
import '../../../catalog/domain/entities/ticket_tier.dart';
import '../../../catalog/presentation/category_style.dart';
import '../../../catalog/presentation/organisms/price_action_bar.dart';
import '../bloc/select_tickets/select_tickets_bloc.dart';
import '../booking_navigation.dart';

/// How many tickets of each kind for an event or a place, and for a place
/// the day of the visit. A race takes one runner. Expects a
/// [SelectTicketsBloc] above it.
class SelectTicketsPage extends StatelessWidget {
  const SelectTicketsPage({super.key});

  void _continue(BuildContext context, SelectTicketsState state) {
    final request = state.request;
    if (request == null) {
      AppToast.show(context, 'Choose at least one ticket');
    } else {
      context.continueWithTickets(request);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SelectTicketsBloc, SelectTicketsState>(
      listenWhen: (previous, current) => current.notice != null && previous.notice != current.notice,
      listener: (context, state) => AppToast.show(context, state.notice!),
      builder: (context, state) {
        final listing = state.listing;
        final isRace = listing is EventListing && listing.needsRunnerDetails;
        final count = state.ticketCount;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: AppColors.surface,
                  child: ScreenHeader(
                    title: isRace ? 'Run category' : 'Select tickets',
                    subtitle: listing.name,
                    onBack: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    children: [
                      if (state.day != null) ...[
                        _VisitDay(state: state),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _TierList(state: state),
                      if (isRace)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            "One runner per booking. The runner's details come next: age, "
                            'emergency contact and T-shirt size.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: PriceActionBar(
            caption: switch (count) {
              0 => 'No tickets selected',
              1 => '1 ticket',
              _ => '$count tickets',
            },
            price: Money.format(state.totalCents),
            actionLabel: 'Continue',
            actionActive: count > 0,
            onAction: () => _continue(context, state),
          ),
        );
      },
    );
  }
}

/// A place: the days it can be visited.
class _VisitDay extends StatelessWidget {
  const _VisitDay({required this.state});

  final SelectTicketsState state;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Day of your visit', style: AppTextStyles.sectionTitle),
          const Text('Tickets are valid all day.', style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          DayStrip(
            days: state.days,
            today: state.days.first,
            selected: state.day!,
            onSelected: (day) => context.read<SelectTicketsBloc>().add(SelectTicketsDayChosen(day)),
          ),
        ],
      ),
    );
  }
}

/// Each kind of ticket with "–" and "+".
class _TierList extends StatelessWidget {
  const _TierList({required this.state});

  final SelectTicketsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SelectTicketsBloc>();
    final category = state.listing.category;

    // A place with a limit per day says what is left on the chosen day.
    String subtitleOf(TicketTier tier) {
      final left = state.availability.leftOf(tier.name);
      final note = switch (left) {
        null => '',
        0 => 'Sold out on this day',
        final left when left <= 10 => 'Only $left left',
        _ => '',
      };
      return [tier.description, note].where((text) => text.isNotEmpty).join(' · ');
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (final (index, tier) in state.tiers.indexed) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.divider),
            QuantityRow(
              leading: IconTile(
                icon: Icons.confirmation_number_outlined,
                background: category.softColor,
                foreground: category.color,
                size: 48,
              ),
              title: tier.name,
              subtitle: subtitleOf(tier),
              price: Money.formatPrice(tier.priceCents),
              quantity: state.quantityOf(tier),
              onAdd: () => bloc.add(SelectTicketsAdded(tier)),
              onRemove: () => bloc.add(SelectTicketsRemoved(tier)),
            ),
          ],
        ],
      ),
    );
  }
}
