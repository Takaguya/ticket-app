import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/filter_pill.dart';
import '../../../../design_system/molecules/list_row.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/molecules/search_field.dart';
import '../../../../design_system/molecules/segmented_control.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../auth/presentation/organisms/account_sheet.dart';
import '../../../dashboard/domain/entities/business_snapshot.dart';
import '../../../dashboard/presentation/bloc/business/business_bloc.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_filter.dart';
import '../../domain/entities/bookings_csv.dart';
import '../bloc/bookings_filter/bookings_filter_bloc.dart';
import '../organisms/booking_status_badge.dart';

/// Saves or shares the bookings export. Null for scanners, who cannot
/// download the list.
typedef BookingsDownload = Future<void> Function(CsvFile file);

/// Search and filter the bookings of one event. Expects [BusinessBloc] and
/// [BookingsFilterBloc] above it.
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key, this.onDownload});

  /// Set for owners only.
  final BookingsDownload? onDownload;

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessBloc>().state;
    final filterState = context.watch<BookingsFilterBloc>().state;
    final snapshot = business.snapshot;

    if (business.status == BusinessStatus.loading) {
      return const _Frame(body: MessageView.loading());
    }
    if (snapshot == null) {
      return const _Frame(
        body: MessageView(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load bookings',
          message: 'Check your connection and open the app again.',
        ),
      );
    }

    // Today's event first, then upcoming; past events most recent first.
    final live = snapshot.liveEvent;
    // A place is open every day, so it is both live and upcoming: listed once.
    final current = [
      ?live,
      for (final event in snapshot.upcomingEvents)
        if (event.id != live?.id) event,
    ];
    final past = snapshot.pastEvents;
    final selected =
        snapshot.eventById(filterState.eventId ?? '') ??
        (current.isNotEmpty ? current.first : (past.isNotEmpty ? past.first : null));
    if (selected == null) {
      return const _Frame(
        body: MessageView(
          icon: Icons.receipt_long_outlined,
          title: 'No events yet',
          message: 'Bookings appear here once an event is on sale.',
        ),
      );
    }

    final showingPast = past.contains(selected);
    final eventBookings = snapshot.bookingsOf(selected.id);
    final searched = BookingSearch.search(eventBookings, filterState.query);
    final rows = searched.where(filterState.filter.accepts).toList();
    final filterBloc = context.read<BookingsFilterBloc>();

    void pickScope(bool wantPast) {
      final events = wantPast ? past : current;
      if (events.isEmpty) {
        AppToast.show(context, wantPast ? 'No past events yet' : 'No current events');
      } else {
        filterBloc.add(BookingsEventSelected(events.first.id));
      }
    }

    Future<void> download() async {
      if (rows.isEmpty) return AppToast.show(context, 'No bookings to download');
      await onDownload!(
        BookingsCsv.build(event: selected, bookings: rows, filter: filterState.filter),
      );
    }

    return Column(
      children: [
        ScreenHeader(
          title: 'Bookings',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onDownload != null) _DownloadButton(onTap: download),
              const AccountButton(),
            ],
          ),
          bottom: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              SegmentedControl<bool>(
                height: 40,
                options: const [
                  SegmentOption(value: false, label: 'Current'),
                  SegmentOption(value: true, label: 'Past'),
                ],
                selected: showingPast,
                onChanged: pickScope,
              ),
              const SizedBox(height: 10),
              _HorizontalStrip(
                height: 48,
                children: [
                  for (final event in showingPast ? past : current)
                    _EventChip(
                      event: event,
                      when: _whenLabel(event, snapshot),
                      selected: event.id == selected.id,
                      onTap: () => filterBloc.add(BookingsEventSelected(event.id)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SearchField(
                value: filterState.query,
                hintText: 'Name, phone or booking ID',
                onChanged: (query) => filterBloc.add(BookingsQueryChanged(query)),
              ),
              const SizedBox(height: 10),
              _HorizontalStrip(
                height: 36,
                children: [
                  for (final filter in BookingFilter.values)
                    FilterPill(
                      label: filter.label,
                      count: searched.where(filter.accepts).length,
                      selected: filter == filterState.filter,
                      onTap: () => filterBloc.add(BookingsStatusFilterChanged(filter)),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    eventBookings.isEmpty
                        ? 'No bookings for this event yet.'
                        : 'No bookings match.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                )
              : _BookingList(bookings: rows),
        ),
      ],
    );
  }

  static String _whenLabel(Event event, BusinessSnapshot snapshot) {
    if (event.isPlace) return 'Every day';
    return switch (event.timingOn(snapshot.asOf)) {
      EventTiming.today => 'Today',
      EventTiming.upcoming => DateFormat.dayMonth(event.startsAt),
      EventTiming.past => 'Ended ${DateFormat.dayMonth(event.startsAt)}',
    };
  }
}

/// Header plus a body, for the loading and empty states.
class _Frame extends StatelessWidget {
  const _Frame({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ScreenHeader(title: 'Bookings', trailing: AccountButton()),
        Expanded(child: body),
      ],
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            for (final (index, booking) in bookings.indexed)
              ListRow(
                minHeight: 62,
                showDivider: index < bookings.length - 1,
                title: booking.buyerName,
                // A place's ticket is for one day, which is what the owner looks for.
                subtitle: booking.visitDate == null
                    ? '${booking.id} · ${booking.summary}'
                    : '${booking.id} · ${booking.summary} · ${DateFormat.dayMonth(booking.visitDate!)}',
                trailing: BookingStatusBadge(status: booking.status),
                onTap: () => context.pushNamed(
                  AppRoutes.booking,
                  pathParameters: {AppRoutes.bookingIdParam: booking.id},
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of items that scrolls sideways, bleeding to the screen edges.
class _HorizontalStrip extends StatelessWidget {
  const _HorizontalStrip({required this.height, required this.children});

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OverflowBox(
        maxWidth: MediaQuery.sizeOf(context).width,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
          itemBuilder: (_, index) => children[index],
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.event,
    required this.when,
    required this.selected,
    required this.onTap,
  });

  final Event event;
  final String when;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.surface : AppColors.primary;
    final radius = BorderRadius.circular(AppRadii.control);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.primarySoft,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: foreground),
                ),
                Text(
                  when,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    return Material(
      color: AppColors.primarySoft,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Download list',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
