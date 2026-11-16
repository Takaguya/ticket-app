import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../../catalog/domain/entities/listing.dart';
import '../../../../catalog/domain/entities/place_availability.dart';
import '../../../../catalog/domain/entities/ticket_tier.dart';
import '../../../../catalog/domain/usecases/get_place_availability.dart';
import '../../../domain/entities/booking_request.dart';

part 'select_tickets_event.dart';
part 'select_tickets_state.dart';

/// How many tickets of each kind, for an event or a place, and for a place
/// the day of the visit. A race takes one runner per booking. A place can
/// limit each kind of ticket per day: the bloc asks what is left of the chosen
/// day, so people cannot choose more than is left.
class SelectTicketsBloc extends Bloc<SelectTicketsEvent, SelectTicketsState> {
  SelectTicketsBloc({
    required Clock clock,
    required Listing listing,
    this._getPlaceAvailability,
  }) : super(_initialState(clock, listing)) {
    on<SelectTicketsStarted>(_onStarted);
    on<SelectTicketsAdded>(_onAdded);
    on<SelectTicketsRemoved>(_onRemoved);
    on<SelectTicketsDayChosen>(_onDayChosen);
  }

  final GetPlaceAvailability? _getPlaceAvailability;

  /// Most tickets in one booking.
  static const maxTickets = 8;

  /// How many days ahead a place can be booked, today included.
  static const admissionDays = 62;

  static SelectTicketsState _initialState(Clock clock, Listing listing) {
    if (listing is! AdmissionListing) return SelectTicketsState(listing: listing);
    final today = DateFormat.dateOnly(clock.now());
    return SelectTicketsState(
      listing: listing,
      days: [
        for (var i = 0; i < admissionDays; i++) DateTime(today.year, today.month, today.day + i),
      ],
      day: today,
    );
  }

  Future<void> _onStarted(SelectTicketsStarted event, Emitter<SelectTicketsState> emit) {
    return _loadAvailability(emit);
  }

  Future<void> _onDayChosen(SelectTicketsDayChosen event, Emitter<SelectTicketsState> emit) {
    // What was left on the other day no longer counts.
    emit(state.copyWith(day: DateFormat.dateOnly(event.day), availability: PlaceAvailability.unlimited));
    return _loadAvailability(emit);
  }

  /// A place: what is left of the chosen day's limits. When the answer cannot
  /// be had, nothing is limited here; the server still refuses a sold-out day
  /// at checkout.
  Future<void> _loadAvailability(Emitter<SelectTicketsState> emit) async {
    final listing = state.listing;
    final day = state.day;
    final getAvailability = _getPlaceAvailability;
    if (listing is! AdmissionListing || day == null || getAvailability == null) return;

    final result = await getAvailability(PlaceDayQuery(placeId: listing.id, day: day));
    // The person may have chosen another day meanwhile: that day's answer counts.
    if (state.day != day) return;
    result.when(
      success: (availability) {
        // Fewer tickets of a kind may be left on this day than were chosen.
        final fitting = <TicketTier, int>{};
        var reduced = false;
        for (final entry in state.quantities.entries) {
          // "+" then "−" leaves a 0 behind: nothing was chosen, so nothing is lowered.
          if (entry.value == 0) continue;
          final left = availability.leftOf(entry.key.name);
          final quantity = left == null ? entry.value : math.min(entry.value, left);
          if (quantity < entry.value) reduced = true;
          if (quantity > 0) fitting[entry.key] = quantity;
        }
        emit(state.copyWith(availability: availability, quantities: fitting));
        if (reduced) _notify(emit, 'Fewer tickets are left on this day, so your choice was changed');
      },
      failure: (_) {},
    );
  }

  void _onAdded(SelectTicketsAdded event, Emitter<SelectTicketsState> emit) {
    final listing = state.listing;
    final left = state.availability.leftOf(event.tier.name);
    if (left != null && state.quantityOf(event.tier) + 1 > left) {
      _notify(
        emit,
        left == 0
            ? '${event.tier.name} is sold out on this day'
            : 'Only $left ${event.tier.name} left on this day',
      );
      return;
    }
    if (listing is EventListing && listing.needsRunnerDetails) {
      // One runner: "+" on another distance moves the entry there.
      if (state.quantityOf(event.tier) > 0) {
        _notify(emit, 'One runner per booking. Book again for another runner.');
      } else {
        emit(state.copyWith(quantities: {event.tier: 1}));
      }
      return;
    }
    if (state.ticketCount >= maxTickets) {
      _notify(emit, 'Maximum $maxTickets tickets per booking');
      return;
    }
    emit(
      state.copyWith(
        quantities: {...state.quantities, event.tier: state.quantityOf(event.tier) + 1},
      ),
    );
  }

  void _onRemoved(SelectTicketsRemoved event, Emitter<SelectTicketsState> emit) {
    final quantity = state.quantityOf(event.tier);
    if (quantity == 0) return;
    emit(state.copyWith(quantities: {...state.quantities, event.tier: quantity - 1}));
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<SelectTicketsState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
