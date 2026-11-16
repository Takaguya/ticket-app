import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/clock.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/info_row.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_request.dart';
import '../bloc/ticket/ticket_bloc.dart';
import '../organisms/order_lines_card.dart';
import '../organisms/ticket_card.dart';

/// A booking's ticket with its QR code, where to go, and what was paid.
/// Expects a [TicketBloc] above it.
class TicketPage extends StatelessWidget {
  const TicketPage({super.key, required this.clock, this.justIssued = false});

  final Clock clock;

  /// Right after paying: says the tickets were issued.
  final bool justIssued;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketBloc, TicketState>(
      builder: (context, state) {
        final booking = state.booking;
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: booking != null && booking.request.ticketCount == 1
                      ? 'Your ticket'
                      : 'Your tickets',
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: switch (state.status) {
                    TicketStatus.loading => const MessageView.loading(),
                    TicketStatus.failure => MessageView(
                      icon: Icons.confirmation_number_outlined,
                      title: "Can't show this ticket",
                      message: state.errorMessage,
                      actionLabel: 'Try again',
                      onAction: () => context.read<TicketBloc>().add(const TicketStarted()),
                    ),
                    TicketStatus.loaded => _TicketView(
                      booking: booking!,
                      isPast: booking.isPastAt(clock.now()),
                      justIssued: justIssued,
                    ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicketView extends StatelessWidget {
  const _TicketView({required this.booking, required this.isPast, required this.justIssued});

  final Booking booking;
  final bool isPast;
  final bool justIssued;

  @override
  Widget build(BuildContext context) {
    final request = booking.request;
    const gap = SizedBox(height: AppSpacing.sm);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, AppSpacing.lg),
      children: [
        if (justIssued) ...[
          _IssuedBanner(
            title: request.ticketCount == 1 ? 'Ticket issued. ' : 'Tickets issued. ',
            hint: request is BusRequest
                ? 'Show the QR code when you board.'
                : 'Show the QR code at the entrance.',
          ),
          gap,
        ],
        TicketCard(booking: booking, isPast: isPast),
        gap,
        AppCard(
          child: InfoRow(
            icon: Icons.place_outlined,
            iconBackground: AppColors.primarySoft,
            iconColor: AppColors.primary,
            title: request.place,
            subtitle: request.placeDetail,
          ),
        ),
        gap,
        OrderLinesCard(
          request: request,
          discountCents: booking.discountCents,
          promoCode: booking.promoCode,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Paid with ${booking.paidWith.label} on ${DateFormat.full(booking.bookedAt)} · '
          'booking ${booking.id}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

/// Green line at the top right after paying.
class _IssuedBanner extends StatelessWidget {
  const _IssuedBanner({required this.title, required this.hint});

  /// In bold, e.g. "Tickets issued. ".
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.surface),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: hint),
                ],
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}
