import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/organisms/card_grid.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/ticket_category.dart';
import '../bloc/listings/listings_bloc.dart';
import '../catalog_navigation.dart';
import '../category_style.dart';
import '../listing_text.dart';
import '../organisms/listing_poster_card.dart';

/// Everything on sale in one category, as posters two to a row. Expects a
/// [ListingsBloc] for [category] above it.
class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, required this.category});

  final TicketCategory category;

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
              child: ScreenHeader(
                title: category.title,
                onBack: () => context.pop(),
                trailing: IconButton(
                  tooltip: 'Search',
                  onPressed: context.openTicketSearch,
                  icon: const Icon(Icons.search_rounded, color: AppColors.ink),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<ListingsBloc, ListingsState>(
                builder: (context, state) => switch (state.status) {
                  ListingsStatus.initial || ListingsStatus.loading => const MessageView.loading(),
                  ListingsStatus.failure => MessageView(
                    icon: Icons.wifi_off_rounded,
                    title: "Can't load ${category.title.toLowerCase()}",
                    message: state.errorMessage,
                    actionLabel: 'Try again',
                    onAction: () => context.read<ListingsBloc>().add(const ListingsRequested()),
                  ),
                  ListingsStatus.loaded when state.listings.isEmpty => MessageView(
                    icon: category.icon,
                    title: 'Nothing on sale yet',
                    message: 'New ${category.title.toLowerCase()} show up here as soon as they go on sale.',
                  ),
                  ListingsStatus.loaded => RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: context.read<ListingsBloc>().refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      children: [
                        CardGrid(
                          children: [
                            for (final listing in state.listings)
                              ListingPosterCard(
                                listing: listing,
                                subtitle: _subtitle(listing),
                                onTap: () => context.openListing(listing),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Events show their date, films "Daily", places where they are.
  static String _subtitle(Listing listing) {
    return switch (listing) {
      EventListing(:final startsAt) => DateFormat.long(startsAt),
      AdmissionListing(:final venue) => venue,
      FilmListing() || BusRoute() => listing.whenText,
    };
  }
}
