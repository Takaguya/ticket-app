part of 'checkout_bloc.dart';

enum CheckoutStatus {
  ready,

  /// Paying and issuing the tickets.
  paying,

  /// Done: [CheckoutState.booking] is set.
  paid,
}

final class CheckoutState extends Equatable {
  const CheckoutState({
    required this.request,
    this.saveRunner = false,
    this.status = CheckoutStatus.ready,
    this.paymentMethod = PaymentMethod.abaPay,
    this.promotions = const [],
    this.promotion,
    this.booking,
    this.notice,
  });

  final BookingRequest request;

  /// Keep the runner's details on the account.
  final bool saveRunner;
  final CheckoutStatus status;
  final PaymentMethod paymentMethod;

  /// The promo codes on offer.
  final List<Promotion> promotions;

  /// The promo code applied, if any.
  final Promotion? promotion;

  /// Set once [status] is paid.
  final Booking? booking;

  /// A one-off message, e.g. that a promo code is not valid.
  final String? notice;

  int get subtotalCents => request.subtotalCents;

  int get discountCents => promotion?.discountOn(subtotalCents) ?? 0;

  int get totalCents => subtotalCents - discountCents;

  /// Nullable fields that can be cleared take a function.
  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? paymentMethod,
    List<Promotion>? promotions,
    Promotion? Function()? promotion,
    Booking? booking,
    String? Function()? notice,
  }) {
    return CheckoutState(
      request: request,
      saveRunner: saveRunner,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      promotions: promotions ?? this.promotions,
      promotion: promotion == null ? this.promotion : promotion(),
      booking: booking ?? this.booking,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [
    request,
    saveRunner,
    status,
    paymentMethod,
    promotions,
    promotion,
    booking,
    notice,
  ];
}
