import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../auth/presentation/organisms/account_sheet.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/presentation/bloc/check_in/check_in_bloc.dart';
import '../../../dashboard/presentation/bloc/business/business_bloc.dart';
import '../../../events/domain/entities/event.dart';
import '../organisms/booking_id_sheet.dart';
import '../organisms/qr_camera_view.dart';
import '../organisms/scanner_viewport.dart';

/// The dark scanner screen: point the camera at a ticket QR, or type the
/// booking ID. Expects [BusinessBloc] and a [CheckInBloc] above it.
///
/// The camera only runs while the Scan tab is showing: the router keeps
/// other tabs alive with tickers off, and this page checks that.
class ScanPage extends StatelessWidget {
  const ScanPage({super.key, required this.cameraBuilder, this.demoMode = false});

  final QrCameraBuilder cameraBuilder;

  /// With the mock backend there are no real tickets to scan, so the screen
  /// offers sample tickets and a booking ID that works.
  final bool demoMode;

  Future<void> _onCheckInState(BuildContext context, CheckInState state) async {
    switch (state.status) {
      case CheckInStatus.failure:
        AppToast.show(context, state.errorMessage ?? 'Something went wrong');
      case CheckInStatus.decided:
        final bloc = context.read<CheckInBloc>();
        await context.pushNamed(AppRoutes.scanResult, extra: state.result);
        // Back from the result: ready for the next guest.
        bloc.add(const CheckInCleared());
      case CheckInStatus.idle || CheckInStatus.checking:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessBloc>().state;
    final snapshot = business.snapshot;
    final live = snapshot?.liveEvent;
    final summary = live == null ? null : snapshot!.summaryOf(live);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.dark,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                subtitle: live == null || summary == null
                    ? null
                    : '${live.name} · ${summary.checkedIn} of ${summary.sold} in',
              ),
              Expanded(
                child: switch (business.status) {
                  BusinessStatus.loading => const MessageView.loading(),
                  _ when live == null => const MessageView(
                    icon: Icons.event_busy_rounded,
                    title: 'No event today',
                    message: 'Check-in opens on the day of the event.',
                    titleColor: AppColors.surface,
                    messageColor: AppColors.onDarkMuted,
                  ),
                  _ => BlocListener<CheckInBloc, CheckInState>(
                    listenWhen: (previous, current) => previous.status != current.status,
                    listener: _onCheckInState,
                    child: _Scanner(
                      event: live,
                      cameraBuilder: cameraBuilder,
                      demoBookings: demoMode ? snapshot!.bookingsOf(live.id) : null,
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page - 6, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scan tickets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.surface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
                  ),
                ],
              ],
            ),
          ),
          const AccountButton(onDark: true),
        ],
      ),
    );
  }
}

class _Scanner extends StatelessWidget {
  const _Scanner({required this.event, required this.cameraBuilder, required this.demoBookings});

  final Event event;
  final QrCameraBuilder cameraBuilder;

  /// Today's bookings in demo mode, otherwise null.
  final List<Booking>? demoBookings;

  void _check(BuildContext context, String code, {bool fromCamera = false}) {
    context.read<CheckInBloc>().add(
      CheckInRequested(eventId: event.id, code: code, fromCamera: fromCamera),
    );
  }

  Future<void> _enterId(BuildContext context) async {
    final digits = await showBookingIdSheet(
      context,
      demoDigits: _firstWith(BookingStatus.open)?.id.substring(2),
    );
    if (digits != null && context.mounted) _check(context, digits);
  }

  Booking? _firstWith(BookingStatus status) {
    for (final booking in demoBookings ?? const <Booking>[]) {
      if (booking.status == status) return booking;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final checking = context.select(
      (CheckInBloc bloc) => bloc.state.status == CheckInStatus.checking,
    );

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(260.0, math.max(150.0, constraints.maxHeight * 0.55));
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - AppSpacing.page * 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScannerViewport(
                        size: size,
                        overlay: checking
                            ? const ColoredBox(
                                color: Color(0x99000000),
                                child: Center(
                                  child: CircularProgressIndicator(color: AppColors.accent),
                                ),
                              )
                            : null,
                        // Off while another tab or a page on top is showing.
                        child: TickerMode.valuesOf(context).enabled
                            ? cameraBuilder(
                                context,
                                (code) => _check(context, code, fromCamera: true),
                              )
                            : const SizedBox.expand(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Point the camera at the ticket QR',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.surface,
                        ),
                      ),
                      if (demoBookings != null) ...[
                        const SizedBox(height: 18),
                        _DemoTickets(
                          onPick: (code) => _check(context, code),
                          valid: _firstWith(BookingStatus.open)?.id,
                          used: _firstWith(BookingStatus.checkedIn)?.id,
                          cancelled: _firstWith(BookingStatus.cancelled)?.id,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Enter booking ID',
                  height: 50,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.ink,
                  onPressed: () => _enterId(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Search guests',
                  height: 50,
                  backgroundColor: AppColors.darkRaised,
                  foregroundColor: AppColors.surface,
                  onPressed: () => context.goNamed(AppRoutes.bookings),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sample tickets for trying each scan result without a real QR code.
class _DemoTickets extends StatelessWidget {
  const _DemoTickets({required this.onPick, this.valid, this.used, this.cancelled});

  final ValueChanged<String> onPick;
  final String? valid;
  final String? used;
  final String? cancelled;

  /// The demo backend answers "Ticket for another event" for this ID.
  static const _otherEventTicket = 'TK70455218';

  @override
  Widget build(BuildContext context) {
    final tickets = [
      ('Valid', valid),
      ('Already used', used),
      ('Cancelled', cancelled),
      ('Other event', _otherEventTicket),
    ];

    return Column(
      children: [
        const Text(
          'Demo mode: scan a sample ticket',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onDarkMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, code) in tickets)
              if (code != null)
                OutlinedButton(
                  onPressed: () => onPick(code),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.darkBorder),
                    minimumSize: const Size(0, AppSizes.tapTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  child: Text(label),
                ),
          ],
        ),
      ],
    );
  }
}
