import 'package:equatable/equatable.dart';

import 'booking_request.dart';

enum PaymentMethod {
  abaPay('ABA Pay', 'Tap to pay with ABA Mobile'),
  card('Card', 'Visa / Mastercard');

  const PaymentMethod(this.label, this.description);

  final String label;
  final String description;
}

/// What checkout sends: the tickets, how they are paid and an optional
/// promo code. The server works out the price again; the app's total is only
/// a preview.
class Order extends Equatable {
  const Order({
    required this.request,
    required this.paymentMethod,
    this.promoCode,
    this.saveRunner = false,
  });

  final BookingRequest request;
  final PaymentMethod paymentMethod;
  final String? promoCode;

  /// Keep the runner's details on the account for the next race.
  final bool saveRunner;

  @override
  List<Object?> get props => [request, paymentMethod, promoCode, saveRunner];
}
