import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/organisms/business_header.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../auth/domain/entities/business_status.dart' as auth;
import '../../../auth/domain/entities/business_type.dart';
import '../../../auth/domain/entities/merchant_user.dart';
import '../../../auth/presentation/organisms/account_sheet.dart';
import '../../../bookings/domain/entities/sales_summary.dart';
import '../../../bookings/presentation/bloc/bookings_filter/bookings_filter_bloc.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/organisms/event_picture_sheet.dart';
import '../../domain/entities/business_snapshot.dart';
import '../bloc/business/business_bloc.dart';
import '../organisms/business_status_banner.dart';
import '../organisms/today_lists.dart';
import '../organisms/today_summary_cards.dart';

/// Owner's dashboard: today's event at a glance, plus upcoming and past
/// events. Expects [BusinessBloc] and [BookingsFilterBloc] above it.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.user});

  final MerchantUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BusinessHeader(
          businessName: user.businessName,
          userName: user.name,
          roleLabel: user.role.label,
          onTap: () => showAccountSheet(context),
        ),
        Expanded(
          child: BlocBuilder<BusinessBloc, BusinessState>(
            builder: (context, state) {
              final snapshot = state.snapshot;
              return switch (state.status) {
                BusinessStatus.loading => const MessageView.loading(),
                BusinessStatus.ready when snapshot != null => _TodayContent(
                  snapshot: snapshot,
                  user: user,
                ),
                _ => const MessageView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load your events',
                  message: 'Check your connection and open the app again.',
                ),
              };
            },
          ),
        ),
      ],
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.snapshot, required this.user});

  final BusinessSnapshot snapshot;
  final MerchantUser user;

  /// Door sales need an approved business and an approved event; the server
  /// refuses them otherwise, so say why before opening the sale.
  void _sellAtDoor(BuildContext context, Event live, SalesSummary summary) {
    final reason = switch (user.businessStatus) {
      auth.BusinessStatus.pending =>
        'Pin is still reviewing your business. You can sell tickets once it is approved.',
      auth.BusinessStatus.suspended =>
        'Pin has suspended your business. Contact Pin to sell tickets again.',
      auth.BusinessStatus.active when !live.approved =>
        'Pin is still reviewing this event. You can sell tickets once it is approved.',
      auth.BusinessStatus.active when summary.left == 0 => 'Sold out. No tickets left to sell.',
      auth.BusinessStatus.active => null,
    };
    if (reason != null) {
      AppToast.show(context, reason);
    } else {
      context.pushNamed(AppRoutes.doorSale);
    }
  }

  void _openBookingsFor(BuildContext context, String eventId) {
    context.read<BookingsFilterBloc>().add(BookingsEventSelected(eventId));
    context.goNamed(AppRoutes.bookings);
  }

  void _openBooking(BuildContext context, String bookingId) {
    context.pushNamed(
      AppRoutes.booking,
      pathParameters: {AppRoutes.bookingIdParam: bookingId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = snapshot.liveEvent;
    final summary = live == null ? null : snapshot.summaryOf(live);
    final past = snapshot.pastEvents;
    const gap = SizedBox(height: 14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, AppSpacing.lg),
      children: [
        if (user.businessStatus != auth.BusinessStatus.active) ...[
          BusinessStatusBanner(status: user.businessStatus),
          gap,
        ],
        if (live != null && summary != null) ...[
          LiveEventCard(event: live, onEditPicture: () => showEventPictureSheet(context, event: live)),
          gap,
          CheckedInCard(summary: summary),
          gap,
          SalesStatsRow(summary: summary),
          gap,
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Scan tickets',
                  icon: Icons.qr_code_scanner_rounded,
                  height: 50,
                  onPressed: () => context.goNamed(AppRoutes.scan),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Sell at the door',
                  variant: AppButtonVariant.outline,
                  height: 50,
                  onPressed: () => _sellAtDoor(context, live, summary),
                ),
              ),
            ],
          ),
          gap,
          TicketTypeBreakdown(stats: summary.byTicketType),
          gap,
        ] else ...[
          const AppCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No event today', style: AppTextStyles.sectionTitle),
                SizedBox(height: 4),
                Text(
                  "Check-in, door sales and the day's numbers appear here on the day of "
                  'an event.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          gap,
        ],
        UpcomingEventsCard(
          events: snapshot.upcomingEvents,
          summaryOf: snapshot.summaryOf,
          onOpen: (event) => _openBookingsFor(context, event.id),
          onEditPicture: (event) => showEventPictureSheet(context, event: event),
          businessType: user.businessType,
          onCreate: () => context.pushNamed(switch (user.businessType) {
            BusinessType.bus => AppRoutes.createTrip,
            BusinessType.cinema => AppRoutes.createScreening,
            BusinessType.admission => AppRoutes.createPlace,
            _ => AppRoutes.createEvent,
          }),
        ),
        if (past.isNotEmpty) ...[
          gap,
          PastEventsCard(
            events: past,
            summaryOf: snapshot.summaryOf,
            onOpen: (event) => _openBookingsFor(context, event.id),
          ),
        ],
        if (live != null) ...[
          gap,
          LatestCheckInsCard(
            bookings: snapshot.latestCheckIns(live.id),
            currentUserName: user.name,
            onOpen: (booking) => _openBooking(context, booking.id),
            onSeeAll: () => _openBookingsFor(context, live.id),
          ),
        ],
      ],
    );
  }
}
