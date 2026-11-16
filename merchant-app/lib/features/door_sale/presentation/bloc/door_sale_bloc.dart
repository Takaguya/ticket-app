import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/phone_number.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/repositories/bookings_repository.dart';
import '../../../bookings/domain/usecases/sell_at_door.dart';
import '../../../events/domain/entities/event.dart';

// Events ---------------------------------------------------------------------

sealed class DoorSaleEvent extends Equatable {
  const DoorSaleEvent();

  @override
  List<Object?> get props => [];
}

final class DoorSaleQuantityIncreased extends DoorSaleEvent {
  const DoorSaleQuantityIncreased(this.ticketType);

  final String ticketType;

  @override
  List<Object?> get props => [ticketType];
}

final class DoorSaleQuantityDecreased extends DoorSaleEvent {
  const DoorSaleQuantityDecreased(this.ticketType);

  final String ticketType;

  @override
  List<Object?> get props => [ticketType];
}

final class DoorSalePhoneChanged extends DoorSaleEvent {
  const DoorSalePhoneChanged(this.phone);

  final String phone;

  @override
  List<Object?> get props => [phone];
}

final class DoorSalePaymentChanged extends DoorSaleEvent {
  const DoorSalePaymentChanged(this.payment);

  final PaymentMethod payment;

  @override
  List<Object?> get props => [payment];
}

/// "Take payment": move on to collecting the money.
final class DoorSaleCheckoutRequested extends DoorSaleEvent {
  const DoorSaleCheckoutRequested();
}

/// Back from the payment step to the ticket picker.
final class DoorSaleCheckoutCancelled extends DoorSaleEvent {
  const DoorSaleCheckoutCancelled();
}

/// "Cash received" or "Payment received": record the sale.
final class DoorSalePaymentConfirmed extends DoorSaleEvent {
  const DoorSalePaymentConfirmed();
}

// State ----------------------------------------------------------------------

enum DoorSaleStep { selecting, payment, completed }

final class DoorSaleState extends Equatable {
  const DoorSaleState({
    required this.event,
    required this.ticketsLeft,
    this.quantities = const {},
    this.phone = '',
    this.payment = PaymentMethod.cash,
    this.step = DoorSaleStep.selecting,
    this.submitting = false,
    this.sale,
    this.notice,
  });

  /// At most this many tickets in one sale.
  static const maxPerSale = 8;

  final Event event;

  /// Tickets still for sale when the screen opened.
  final int ticketsLeft;

  /// Ticket type name -> quantity.
  final Map<String, int> quantities;
  final String phone;

  /// Cash or KHQR.
  final PaymentMethod payment;
  final DoorSaleStep step;
  final bool submitting;

  /// The booking created, once [step] is [DoorSaleStep.completed].
  final Booking? sale;

  /// One-off message for a toast.
  final String? notice;

  int get count => quantities.values.fold(0, (sum, n) => sum + n);

  int get totalCents {
    return event.ticketTypes.fold(
      0,
      (sum, type) => sum + (quantities[type.name] ?? 0) * type.priceCents,
    );
  }

  int get maxTickets => math.min(maxPerSale, ticketsLeft);
  bool get isPhoneValid => PhoneNumber.isValid(phone);
  bool get canCheckout => count > 0 && isPhoneValid;

  List<BookingLine> get lines => [
    for (final type in event.ticketTypes)
      if ((quantities[type.name] ?? 0) > 0)
        BookingLine(ticketType: type.name, quantity: quantities[type.name]!),
  ];

  DoorSaleState copyWith({
    Map<String, int>? quantities,
    String? phone,
    PaymentMethod? payment,
    DoorSaleStep? step,
    bool? submitting,
    Booking? sale,
    String? Function()? notice,
  }) {
    return DoorSaleState(
      event: event,
      ticketsLeft: ticketsLeft,
      quantities: quantities ?? this.quantities,
      phone: phone ?? this.phone,
      payment: payment ?? this.payment,
      step: step ?? this.step,
      submitting: submitting ?? this.submitting,
      sale: sale ?? this.sale,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [
    event,
    ticketsLeft,
    quantities,
    phone,
    payment,
    step,
    submitting,
    sale,
    notice,
  ];
}

// Bloc -----------------------------------------------------------------------

/// Selling tickets at the entrance: pick quantities, enter the buyer's phone,
/// take cash or KHQR, then optionally admit straight away.
class DoorSaleBloc extends Bloc<DoorSaleEvent, DoorSaleState> {
  DoorSaleBloc({required this._sellAtDoor, required Event event, required int ticketsLeft})
    : super(DoorSaleState(event: event, ticketsLeft: ticketsLeft)) {
    on<DoorSaleQuantityIncreased>(_onIncreased);
    on<DoorSaleQuantityDecreased>(_onDecreased);
    on<DoorSalePhoneChanged>((event, emit) => emit(state.copyWith(phone: event.phone)));
    on<DoorSalePaymentChanged>((event, emit) => emit(state.copyWith(payment: event.payment)));
    on<DoorSaleCheckoutRequested>(_onCheckoutRequested);
    on<DoorSaleCheckoutCancelled>(
      (event, emit) => emit(state.copyWith(step: DoorSaleStep.selecting)),
    );
    on<DoorSalePaymentConfirmed>(_onPaymentConfirmed);
  }

  final SellAtDoor _sellAtDoor;

  void _onIncreased(DoorSaleQuantityIncreased event, Emitter<DoorSaleState> emit) {
    if (state.count >= state.maxTickets) {
      _notify(
        emit,
        state.ticketsLeft < DoorSaleState.maxPerSale
            ? 'Only ${state.ticketsLeft} left'
            : 'Maximum ${DoorSaleState.maxPerSale} tickets per sale',
      );
      return;
    }
    final current = state.quantities[event.ticketType] ?? 0;
    emit(state.copyWith(quantities: {...state.quantities, event.ticketType: current + 1}));
  }

  void _onDecreased(DoorSaleQuantityDecreased event, Emitter<DoorSaleState> emit) {
    final current = state.quantities[event.ticketType] ?? 0;
    if (current == 0) return;
    emit(state.copyWith(quantities: {...state.quantities, event.ticketType: current - 1}));
  }

  void _onCheckoutRequested(DoorSaleCheckoutRequested event, Emitter<DoorSaleState> emit) {
    if (state.count == 0) return _notify(emit, 'Add at least one ticket');
    if (!state.isPhoneValid) return _notify(emit, "Enter the buyer's phone number");
    emit(state.copyWith(step: DoorSaleStep.payment));
  }

  Future<void> _onPaymentConfirmed(
    DoorSalePaymentConfirmed event,
    Emitter<DoorSaleState> emit,
  ) async {
    if (state.submitting || state.step != DoorSaleStep.payment) return;

    emit(state.copyWith(submitting: true));
    final result = await _sellAtDoor(
      DoorSaleRequest(
        eventId: state.event.id,
        lines: state.lines,
        buyerPhone: PhoneNumber.toE164(state.phone),
        payment: state.payment,
      ),
    );
    result.when(
      success: (sale) => emit(
        state.copyWith(submitting: false, step: DoorSaleStep.completed, sale: sale),
      ),
      failure: (failure) {
        emit(state.copyWith(submitting: false));
        _notify(emit, failure.message);
      },
    );
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<DoorSaleState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
