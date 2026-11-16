import 'package:equatable/equatable.dart';

/// Where a booking is in its life. A user's "Confirmed" ticket is [open]
/// here, and their "Used" ticket is [checkedIn].
enum BookingStatus {
  open('Not checked in'),
  checkedIn('Checked in'),
  cancelled('Cancelled');

  const BookingStatus(this.label);

  final String label;
}

enum PaymentMethod {
  abaKhqr('ABA / KHQR'),
  card('Card'),
  cash('Cash');

  const PaymentMethod(this.label);

  final String label;
}

/// How the booking was sold. Door sales exist only on the merchant side and
/// carry no Pin commission.
enum SalesChannel {
  online('Online'),
  door('At the door');

  const SalesChannel(this.label);

  final String label;
}

/// Tickets of one type on a booking, e.g. 2× "10K".
class BookingLine extends Equatable {
  const BookingLine({required this.ticketType, required this.quantity});

  /// Matches [TicketType.name] of the event exactly.
  final String ticketType;
  final int quantity;

  @override
  List<Object?> get props => [ticketType, quantity];
}

/// When a booking was admitted and by whom.
class CheckIn extends Equatable {
  const CheckIn({required this.at, required this.staffName});

  final DateTime at;
  final String staffName;

  @override
  List<Object?> get props => [at, staffName];
}

/// Why the owner cancelled a booking. The names are what the API sends.
enum CancelReason {
  buyerAsked('The buyer asked to cancel'),
  eventChanged('The event changed or was called off'),
  soldByMistake('Sold by mistake'),
  other('Other reason');

  const CancelReason(this.label);

  final String label;
}

/// When the business cancelled a booking, who did it and why.
class Cancellation extends Equatable {
  const Cancellation({
    required this.at,
    required this.staffName,
    required this.reason,
    required this.refundCents,
  });

  final DateTime at;
  final String staffName;
  final CancelReason reason;

  /// What Pin paid back to the buyer: everything they paid for an online
  /// booking. 0 for a door sale, which the business pays back itself.
  final int refundCents;

  @override
  List<Object?> get props => [at, staffName, reason, refundCents];
}

/// A race runner's details, for the whole team.
class Runner extends Equatable {
  const Runner({
    required this.name,
    required this.phone,
    this.email,
    required this.gender,
    required this.age,
    required this.nationality,
    required this.emergencyName,
    required this.emergencyPhone,
    required this.shirtSize,
  });

  final String name;
  final String phone;
  final String? email;

  /// As the API sends it: `female`, `male` or `other`.
  final String gender;
  final int age;
  final String nationality;
  final String emergencyName;
  final String emergencyPhone;
  final String shirtSize;

  @override
  List<Object?> get props => [
    name,
    phone,
    email,
    gender,
    age,
    nationality,
    emergencyName,
    emergencyPhone,
    shirtSize,
  ];
}

/// One purchase. Both apps share this record; the user app issues the ID.
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.eventId,
    required this.buyerName,
    required this.phone,
    required this.lines,
    required this.totalCents,
    required this.payment,
    required this.channel,
    required this.status,
    this.promoCode,
    this.tshirtSizes = const [],
    this.checkIn,
    this.cancellation,
    this.runner,
    this.seats = const [],
    this.visitDate,
  });

  /// `TK` followed by 8 digits.
  final String id;
  final String eventId;
  final String buyerName;
  final String phone;
  final List<BookingLine> lines;

  /// The tickets' full price, which the business is paid on. A Pin promo code
  /// lowers what the buyer paid, not this: Pin pays for the discount.
  final int totalCents;

  /// The Pin promo code the buyer used, if any.
  final String? promoCode;
  final PaymentMethod payment;
  final SalesChannel channel;
  final BookingStatus status;

  /// One per ticket, running events only.
  final List<String> tshirtSizes;

  /// Set when [status] is [BookingStatus.checkedIn].
  final CheckIn? checkIn;

  /// Set when the business cancelled the booking. Older cancelled bookings
  /// (the demo's) have none.
  final Cancellation? cancellation;

  /// Set for a race booked in the Pin app.
  final Runner? runner;

  /// The seats of a bus trip, one per ticket, e.g. `1A`; empty for any other
  /// event. A cancelled booking keeps them, but they are free again.
  final List<String> seats;

  /// The day a place's tickets are good for (a date, no time); null for any
  /// other event. The tickets can be scanned on that day only.
  final DateTime? visitDate;

  /// A booking is admitted as a whole: this many people walk in together.
  int get ticketCount => lines.fold(0, (sum, line) => sum + line.quantity);

  /// `2× 10K, 1× 5K Fun run`
  String get summary => lines.map((line) => '${line.quantity}× ${line.ticketType}').join(', ');

  /// Cancelled bookings leave the sold, revenue and commission totals.
  bool get countsAsSold => status != BookingStatus.cancelled;

  int quantityOf(String ticketType) {
    return lines
        .where((line) => line.ticketType == ticketType)
        .fold(0, (sum, line) => sum + line.quantity);
  }

  @override
  List<Object?> get props => [
    id,
    eventId,
    buyerName,
    phone,
    lines,
    totalCents,
    payment,
    channel,
    status,
    promoCode,
    tshirtSizes,
    checkIn,
    cancellation,
    runner,
    seats,
    visitDate,
  ];
}
