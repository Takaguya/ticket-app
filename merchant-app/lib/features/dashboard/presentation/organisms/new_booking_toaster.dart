import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design_system/molecules/app_toast.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../domain/entities/business_snapshot.dart';
import '../bloc/business/business_bloc.dart';

/// Shows a toast when someone books in the Pin user app, as the merchant
/// prototype does: "New booking from the Pin app · Bopha Keo · 2 tickets".
/// Expects a [BusinessBloc] above it.
class NewBookingToaster extends StatefulWidget {
  const NewBookingToaster({super.key, required this.child});

  final Widget child;

  /// The toast text for bookings that just arrived.
  static String messageFor(List<Booking> fresh) {
    if (fresh.length > 1) return '${fresh.length} new bookings from the Pin app';
    final booking = fresh.single;
    final tickets = booking.ticketCount == 1 ? '1 ticket' : '${booking.ticketCount} tickets';
    return 'New booking from the Pin app · ${booking.buyerName} · $tickets';
  }

  @override
  State<NewBookingToaster> createState() => _NewBookingToasterState();
}

class _NewBookingToasterState extends State<NewBookingToaster> {
  /// The snapshot new ones are compared with. Starts with what is already shown,
  /// so opening the app never announces old bookings.
  BusinessSnapshot? _last;

  @override
  void initState() {
    super.initState();
    _last = context.read<BusinessBloc>().state.snapshot;
  }

  void _onState(BuildContext context, BusinessState state) {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    final previous = _last;
    _last = snapshot;
    if (previous == null) return;

    final fresh = snapshot.newOnlineBookingsSince(previous);
    if (fresh.isNotEmpty) AppToast.show(context, NewBookingToaster.messageFor(fresh));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BusinessBloc, BusinessState>(listener: _onState, child: widget.child);
  }
}
