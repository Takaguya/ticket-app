import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/result/result.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../../core/utils/money.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/entities/booking_request.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/promotion.dart';
import '../../../domain/usecases/get_promotions.dart';
import '../../../domain/usecases/place_order.dart';

part 'checkout_event.dart';
part 'checkout_state.dart';

/// The last step: how to pay, an optional promo code, then paying. The total
/// shown is a preview; the server works out the price again.
class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc({
    required this._getPromotions,
    required this._placeOrder,
    required BookingRequest request,
    bool saveRunner = false,
  }) : super(CheckoutState(request: request, saveRunner: saveRunner)) {
    on<CheckoutStarted>(_onStarted);
    on<CheckoutPaymentMethodChosen>(
      (event, emit) => emit(state.copyWith(paymentMethod: event.method)),
    );
    on<CheckoutPromoCodeEntered>(_onPromoCodeEntered);
    on<CheckoutPromotionRemoved>((event, emit) => emit(state.copyWith(promotion: () => null)));
    on<CheckoutConfirmed>(_onConfirmed);
  }

  final GetPromotions _getPromotions;
  final PlaceOrder _placeOrder;

  Future<void> _onStarted(CheckoutStarted event, Emitter<CheckoutState> emit) async {
    // Without the offers, checkout works the same; only codes cannot be used.
    if (await _getPromotions(const NoParams()) case Success(value: final promotions)) {
      emit(state.copyWith(promotions: promotions));
    }
  }

  void _onPromoCodeEntered(CheckoutPromoCodeEntered event, Emitter<CheckoutState> emit) {
    final code = event.code.trim();
    if (code.isEmpty) return;
    final promotion = state.promotions.where((offer) => offer.matches(code)).firstOrNull;
    if (promotion == null) {
      _notify(emit, '${code.toUpperCase()} is not a valid promo code.');
      return;
    }
    if (!promotion.appliesTo(state.subtotalCents)) {
      _notify(
        emit,
        '${promotion.code} needs an order of ${Money.format(promotion.minimumSpendCents)} or more.',
      );
      return;
    }
    emit(state.copyWith(promotion: () => promotion));
    _notify(emit, '${promotion.code} applied: ${promotion.title}');
  }

  Future<void> _onConfirmed(CheckoutConfirmed event, Emitter<CheckoutState> emit) async {
    if (state.status != CheckoutStatus.ready) return;
    emit(state.copyWith(status: CheckoutStatus.paying));
    final result = await _placeOrder(
      Order(
        request: state.request,
        paymentMethod: state.paymentMethod,
        promoCode: state.promotion?.code,
        saveRunner: state.saveRunner,
      ),
    );
    switch (result) {
      case Success(value: final booking):
        emit(state.copyWith(status: CheckoutStatus.paid, booking: booking));
      case FailureResult(:final failure):
        emit(state.copyWith(status: CheckoutStatus.ready));
        _notify(emit, failure.message);
    }
  }

  /// Puts a one-off message in the state, then clears it so the same message
  /// can be shown again later.
  void _notify(Emitter<CheckoutState> emit, String message) {
    emit(state.copyWith(notice: () => message));
    emit(state.copyWith(notice: () => null));
  }
}
