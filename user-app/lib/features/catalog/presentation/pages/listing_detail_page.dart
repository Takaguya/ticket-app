import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_back_button.dart';
import '../../../../design_system/atoms/circle_icon_button.dart';
import '../../../../design_system/atoms/picture_placeholder.dart';
import '../../../../design_system/molecules/remote_image.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/info_row.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../booking/domain/entities/booking_request.dart';
import '../../../booking/presentation/booking_navigation.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/showtime.dart';
import '../bloc/listing_detail/listing_detail_bloc.dart';
import '../category_style.dart';
import '../organisms/price_action_bar.dart';
import '../organisms/showtime_picker.dart';
import '../organisms/ticket_tier_list.dart';

/// An event's, film's or place's page: what it is, when and where, the
/// tickets (or a film's showtimes) and the price. Expects a
/// [ListingDetailBloc] above it.
class ListingDetailPage extends StatelessWidget {
  const ListingDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListingDetailBloc, ListingDetailState>(
      builder: (context, state) {
        final listing = state.listing;
        if (state.status == ListingDetailStatus.loaded && listing != null) {
          return _ListingView(listing: listing, state: state);
        }
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 6),
                  child: AppBackButton(onPressed: () => context.pop()),
                ),
                Expanded(
                  child: state.status == ListingDetailStatus.failure
                      ? MessageView(
                          icon: Icons.event_busy_outlined,
                          title: "Can't show this",
                          message: state.errorMessage,
                          actionLabel: 'Try again',
                          onAction: () =>
                              context.read<ListingDetailBloc>().add(const ListingDetailStarted()),
                        )
                      : const MessageView.loading(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListingView extends StatelessWidget {
  const _ListingView({required this.listing, required this.state});

  final Listing listing;
  final ListingDetailState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The page scrolls below the status bar, never under it.
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(child: _content(context)),
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  Widget _content(BuildContext context) {
    final category = listing.category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 230,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RemoteImage(
                path: listing.imageUrl,
                fallback: PicturePlaceholder(caption: listing.name, icon: listing.icon, color: category.color),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              listing.tagBadge(),
              const SizedBox(height: 8),
              Text(listing.name, style: AppTextStyles.headline),
              const SizedBox(height: 14),
              ..._facts(),
              if (_about.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('About', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 6),
                Text(_about, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Panel(child: _choice(context)),
        const SizedBox(height: AppSpacing.xs),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good to know', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              for (final line in _goodToKnow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('•  $line', style: AppTextStyles.body.copyWith(fontSize: 14)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// When and where.
  List<Widget> _facts() {
    const gap = SizedBox(height: 10);
    return switch (listing) {
      EventListing(:final startsAt, :final venue, :final venueDetail) => [
        _when(DateFormat.long(startsAt), 'Starts ${DateFormat.time(startsAt)}'),
        gap,
        _where(venue, venueDetail),
      ],
      AdmissionListing(:final venue, :final venueDetail) => [
        _when('Any day', 'Choose your date when you book'),
        gap,
        _where(venue, venueDetail),
      ],
      FilmListing(:final rating, :final genre, :final runtime, :final releasedOn) => [
        _when('Now showing', '$rating · $genre · ${DateFormat.duration(runtime)}'),
        gap,
        InfoRow(
          icon: Icons.event_available_outlined,
          iconBackground: AppColors.busSoft,
          iconColor: AppColors.bus,
          title: 'Released ${DateFormat.full(releasedOn)}',
          subtitle: 'In theatres now',
        ),
      ],
      BusRoute(:final origin, :final destination) => [_where('$origin → $destination', null)],
    };
  }

  static Widget _when(String title, String subtitle) {
    return InfoRow(
      icon: Icons.calendar_month_outlined,
      iconBackground: AppColors.warningSoft,
      iconColor: AppColors.warning,
      title: title,
      subtitle: subtitle,
    );
  }

  static Widget _where(String title, String? subtitle) {
    return InfoRow(
      icon: Icons.place_outlined,
      iconBackground: AppColors.primarySoft,
      iconColor: AppColors.primary,
      title: title,
      subtitle: subtitle,
    );
  }

  String get _about => switch (listing) {
    EventListing(:final about) || AdmissionListing(:final about) || FilmListing(:final about) => about,
    BusRoute() => '',
  };

  List<String> get _goodToKnow => [
    'E-ticket with QR code, no printing needed',
    ...switch (listing) {
      EventListing(:final policy, :final organiser) ||
      AdmissionListing(:final policy, :final organiser) => [
        policy,
        if (organiser.trim().isNotEmpty) 'Organiser: $organiser',
      ],
      FilmListing(:final policy) => [policy],
      BusRoute() => const <String>[],
    },
  ].where((line) => line.trim().isNotEmpty).toList();

  /// The tickets on sale, or a film's days and showtimes.
  Widget _choice(BuildContext context) {
    final tiers = switch (listing) {
      EventListing(:final tiers) || AdmissionListing(:final tiers) => tiers,
      FilmListing() || BusRoute() => null,
    };
    if (tiers != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tickets', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          TicketTierList(tiers: tiers),
        ],
      );
    }

    final bloc = context.read<ListingDetailBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Select theatre & time', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 12),
        if (state.selectedDay != null && state.today != null)
          ShowtimePicker(
            days: state.days,
            today: state.today!,
            selectedDay: state.selectedDay!,
            onDaySelected: (day) => bloc.add(ListingDetailDayChosen(day)),
            theatres: state.theatres,
            loading: state.showtimesLoading,
            selectedShowtimeId: state.selectedShowtime?.id,
            onShowtimeSelected: (show) => bloc.add(ListingDetailShowtimeChosen(show)),
          ),
        if (state.showtimesError != null)
          Text(state.showtimesError!, style: AppTextStyles.error),
      ],
    );
  }

  Widget _bottomBar(BuildContext context) {
    if (listing case final FilmListing film) {
      final show = state.selectedShowtime;
      return PriceActionBar(
        caption: show == null
            ? 'From'
            : '${DateFormat.weekday(show.startsAt)} ${DateFormat.dayMonth(show.startsAt)} · '
                  '${DateFormat.time(show.startsAt)} · ${show.hall}',
        price: Money.format(show?.priceCents ?? listing.fromPriceCents),
        actionLabel: 'Select seats',
        actionActive: show != null,
        onAction: show == null
            ? () => AppToast.show(context, 'Choose a day and a time first')
            : () => _chooseSeats(context, film, show),
      );
    }
    return PriceActionBar(
      caption: 'From',
      price: Money.formatPrice(listing.fromPriceCents),
      actionLabel: 'Select tickets',
      onAction: () => context.selectTickets(listing),
    );
  }

  void _chooseSeats(BuildContext context, FilmListing film, Showtime show) {
    final theatre = state.theatres.firstWhere((t) => t.showtimes.contains(show)).theatre;
    context.chooseSeats(CinemaRequest(film: film, theatre: theatre, showtime: show));
  }
}

/// White band across the page.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 18, AppSpacing.page, 18),
        child: child,
      ),
    );
  }
}
