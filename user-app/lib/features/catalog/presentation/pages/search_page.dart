import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/atoms/app_back_button.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/search_field.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../bloc/search/search_bloc.dart';
import '../catalog_navigation.dart';
import '../listing_text.dart';
import '../organisms/listing_row.dart';

/// Search events, bus routes, films and places by name or place. Expects a
/// [SearchBloc] above it.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, AppSpacing.page, 10),
                child: Row(
                  children: [
                    AppBackButton(onPressed: () => context.pop()),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SearchField(
                        hintText: 'Search events, routes, movies',
                        autofocus: true,
                        onChanged: (query) =>
                            context.read<SearchBloc>().add(SearchQueryChanged(query)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  if (state.status == SearchStatus.idle) {
                    return const MessageView(
                      icon: Icons.search_rounded,
                      title: 'What are you looking for?',
                      message: 'Search by name or place, e.g. "rock", "Siem Reap" or "Khmer".',
                    );
                  }
                  if (state.status == SearchStatus.failure) {
                    return MessageView(
                      icon: Icons.wifi_off_rounded,
                      title: "Can't search right now",
                      message: state.errorMessage,
                    );
                  }
                  if (state.results.isEmpty) {
                    return state.status == SearchStatus.searching
                        ? const MessageView.loading()
                        : MessageView(
                            icon: Icons.search_off_rounded,
                            title: 'Nothing found',
                            message: 'Nothing matches "${state.query}". Try another word.',
                          );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: state.results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final listing = state.results[index];
                      return ListingRow(
                        listing: listing,
                        subtitle: listing.summaryText,
                        showTag: true,
                        onTap: () => context.openListing(listing),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
