import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/molecules/search_field.dart';
import '../../../../design_system/molecules/section_header.dart';
import '../../../../design_system/organisms/card_grid.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/available_categories.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/ticket_category.dart';
import '../bloc/listings/listings_bloc.dart';
import '../catalog_navigation.dart';
import '../listing_text.dart';
import '../organisms/bus_route_card.dart';
import '../organisms/category_shortcuts.dart';
import '../organisms/listing_poster_card.dart';
import '../organisms/listing_row.dart';

/// "Tickets": events, buses, cinema and places, with search. Expects a
/// [ListingsBloc] for every category above it. Categories that are not
/// [available] yet show "Soon".
class TicketsHubPage extends StatelessWidget {
  const TicketsHubPage({super.key, this.available = AvailableCategories.all});

  final AvailableCategories available;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(title: 'Tickets', onBack: () => context.pop()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Events, buses, cinema & more', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 10),
                        SearchField(
                          hintText: 'Search events, routes, movies',
                          onTap: context.openTicketSearch,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _HubBody(available: available)),
          ],
        ),
      ),
    );
  }
}

class _HubBody extends StatelessWidget {
  const _HubBody({required this.available});

  final AvailableCategories available;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListingsBloc, ListingsState>(
      builder: (context, state) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: context.read<ListingsBloc>().refresh,
          child: ListView(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page - 4),
                child: CategoryShortcuts(
                  available: available,
                  onSelected: context.openCategory,
                  onComingSoon: (category) =>
                      AppToast.show(context, '${category.title} is coming soon.'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...switch (state.status) {
                ListingsStatus.initial || ListingsStatus.loading => [
                  const SizedBox(height: 160, child: MessageView.loading()),
                ],
                ListingsStatus.failure => [
                  MessageView(
                    icon: Icons.wifi_off_rounded,
                    title: "Can't load tickets",
                    message: state.errorMessage,
                    actionLabel: 'Try again',
                    onAction: () => context.read<ListingsBloc>().add(const ListingsRequested()),
                  ),
                ],
                ListingsStatus.loaded => _sections(context, state),
              },
            ],
          ),
        );
      },
    );
  }

  List<Widget> _sections(BuildContext context, ListingsState state) {
    final events = state.listingsOf<EventListing>();
    final routes = state.listingsOf<BusRoute>();
    final films = state.listingsOf<FilmListing>();
    const pad = EdgeInsets.symmetric(horizontal: AppSpacing.page);

    return [
      if (events.isNotEmpty) ...[
        Padding(
          padding: pad,
          child: SectionHeader(
            title: 'Happening this month',
            onSeeAll: () => context.openCategory(TicketCategory.events),
          ),
        ),
        CardCarousel(
          cardWidth: 200,
          children: [
            for (final event in events)
              ListingPosterCard(
                listing: event,
                subtitle: event.venue,
                showTag: true,
                onTap: () => context.openListing(event),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (routes.isNotEmpty) ...[
        Padding(
          padding: pad,
          child: SectionHeader(
            title: 'Popular bus routes',
            onSeeAll: () => context.openCategory(TicketCategory.bus),
          ),
        ),
        for (final route in routes)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
            child: BusRouteCard(route: route, onTap: () => context.openListing(route)),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (films.isNotEmpty) ...[
        Padding(
          padding: pad,
          child: SectionHeader(
            title: 'Now showing',
            onSeeAll: () => context.openCategory(TicketCategory.cinema),
          ),
        ),
        CardCarousel(
          cardWidth: 150,
          children: [
            for (final film in films)
              ListingPosterCard(
                listing: film,
                subtitle: film.placeText,
                onTap: () => context.openListing(film),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      const Padding(padding: pad, child: SectionHeader(title: 'All tickets')),
      for (final listing in state.listings)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
          child: ListingRow(
            listing: listing,
            subtitle: listing.summaryText,
            showTag: true,
            onTap: () => context.openListing(listing),
          ),
        ),
    ];
  }
}
