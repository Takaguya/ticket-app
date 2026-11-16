part of 'checkout_bloc.dart';

sealed class CheckoutEvent extends Equatable {
  const CheckoutEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened: load the promo codes on offer.
final class CheckoutStarted extends CheckoutEvent {
  const CheckoutStarted();
}

final class CheckoutPaymentMethodChosen extends CheckoutEvent {
  const CheckoutPaymentMethodChosen(this.method);

  final PaymentMethod method;

  @override
  List<Object?> get props => [method];
}

/// A promo code typed, or an offer tapped.
final class CheckoutPromoCodeEntered extends CheckoutEvent {
  const CheckoutPromoCodeEntered(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

final class CheckoutPromotionRemoved extends CheckoutEvent {
  const CheckoutPromotionRemoved();
}

/// "Confirm": pay and issue the tickets.
final class CheckoutConfirmed extends CheckoutEvent {
  const CheckoutConfirmed();
}
