import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/molecules/segmented_control.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../booking/presentation/bloc/bookings/bookings_bloc.dart';
import '../../../booking/presentation/booking_navigation.dart';
import '../../../booking/presentation/organisms/booking_card.dart';

/// The Activity tab: the person's bookings, upcoming and past. Tapping one
/// opens its ticket. Expects a [BookingsBloc] above it.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

enum _Period { upcoming, past }

class _ActivityPageState extends State<ActivityPage> {
  _Period _period = _Period.upcoming;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Activity'),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
              child: SegmentedControl<_Period>(
                options: const [
                  SegmentOption(value: _Period.upcoming, label: 'Upcoming'),
                  SegmentOption(value: _Period.past, label: 'Past'),
                ],
                selected: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.background,
                child: BlocBuilder<BookingsBloc, BookingsState>(
                  builder: (context, state) => switch (state.status) {
                    BookingsStatus.loading => const MessageView.loading(),
                    BookingsStatus.failure => MessageView(
                      icon: Icons.cloud_off_outlined,
                      title: "Can't show your bookings",
                      message: state.errorMessage,
                      actionLabel: 'Try again',
                      onAction: () => context.read<BookingsBloc>().add(const BookingsStarted()),
                    ),
                    BookingsStatus.loaded => _period == _Period.upcoming
                        ? _list(state.upcoming, isPast: false)
                        : _list(state.past, isPast: true),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Booking> bookings, {required bool isPast}) {
    if (bookings.isEmpty) {
      return isPast
          ? const MessageView(
              icon: Icons.history_rounded,
              title: 'No past bookings',
              message: 'Events you have been to and trips you took show up here.',
            )
          : MessageView(
              icon: Icons.confirmation_number_outlined,
              title: 'No upcoming bookings',
              message: 'Tickets you book show up here, with their QR code.',
              actionLabel: 'Find tickets',
              onAction: () => context.pushNamed(AppRoutes.tickets),
            );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.page),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => BookingCard(
        booking: bookings[index],
        isPast: isPast,
        onTap: () => context.openTicket(bookings[index]),
      ),
    );
  }
}
