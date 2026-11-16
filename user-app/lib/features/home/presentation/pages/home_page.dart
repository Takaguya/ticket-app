import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/clock.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/app_logo.dart';
import '../../../../design_system/atoms/picture_placeholder.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/section_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../catalog/domain/entities/listing.dart';
import '../../../catalog/domain/entities/ticket_category.dart';
import '../../../catalog/presentation/bloc/listings/listings_bloc.dart';
import '../../../catalog/presentation/catalog_navigation.dart';
import '../../../catalog/presentation/organisms/listing_row.dart';
import '../organisms/service_shortcuts.dart';

/// The Home tab: a greeting, search, Pin's services and popular events.
/// Expects a [ListingsBloc] for every category above it.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.firstName, this.clock = const Clock()});

  final String firstName;
  final Clock clock;

  /// "Good morning", "Good afternoon" or "Good evening".
  static String greetingFor(DateTime time) {
    if (time.hour < 12) return 'Good morning';
    if (time.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: context.read<ListingsBloc>().refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(greeting: '${greetingFor(clock.now())}, $firstName'),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SearchCard(),
                  const SizedBox(height: AppSpacing.sm),
                  ServiceShortcuts(
                    onTickets: () => context.pushNamed(AppRoutes.tickets),
                    onComingSoon: (service) => AppToast.show(context, '$service is coming soon.'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: const SizedBox(
                      height: 130,
                      child: PicturePlaceholder(
                        caption: 'Offers and news from Pin',
                        icon: Icons.campaign_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _PopularEvents(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const AppLogo(height: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.screenTitle.copyWith(color: AppColors.surface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search, with quick picks underneath: the next event and a popular route.
class _SearchCard extends StatelessWidget {
  const _SearchCard();

  @override
  Widget build(BuildContext context) {
    final picks = context.select((ListingsBloc bloc) {
      final state = bloc.state;
      return <Listing>[
        ...state.listingsOf<EventListing>().take(1),
        ...state.listingsOf<BusRoute>().take(1),
      ];
    });

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Search events, routes, movies',
            excludeSemantics: true,
            child: InkWell(
              onTap: context.openTicketSearch,
              child: const SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.place_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search events, routes, movies',
                        style: TextStyle(fontSize: 16, color: AppColors.placeholder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (picks.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final pick in picks) _QuickPick(listing: pick)],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickPick extends StatelessWidget {
  const _QuickPick({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.openListing(listing),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  listing.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularEvents extends StatelessWidget {
  const _PopularEvents();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListingsBloc, ListingsState>(
      builder: (context, state) {
        final events = state.listingsOf<EventListing>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Popular events',
              onSeeAll: () => context.openCategory(TicketCategory.events),
            ),
            ...switch (state.status) {
              ListingsStatus.initial || ListingsStatus.loading => [
                const SizedBox(height: 120, child: MessageView.loading()),
              ],
              ListingsStatus.failure => [
                MessageView(
                  title: "Can't load events",
                  message: state.errorMessage,
                  actionLabel: 'Try again',
                  onAction: () => context.read<ListingsBloc>().add(const ListingsRequested()),
                ),
              ],
              ListingsStatus.loaded => [
                for (final event in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: ListingRow(
                      listing: event,
                      subtitle: event.venue,
                      onTap: () => context.openListing(event),
                    ),
                  ),
              ],
            },
          ],
        );
      },
    );
  }
}
