import '../../../../core/utils/phone_number.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/repositories/bookings_repository.dart';

/// Bookings and scan results as the Pin API sends them. Enum values are the
/// app's own names (`abaKhqr`, `checkedIn`, ...); times are local without an
/// offset, e.g. `2026-11-12T05:12:40`.
abstract final class BookingJson {
  static Booking booking(Map<String, dynamic> json) {
    final checkIn = json['checkIn'] as Map<String, dynamic>?;
    final cancellation = json['cancellation'] as Map<String, dynamic>?;
    final runner = json['runner'] as Map<String, dynamic>?;
    return Booking(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      buyerName: json['buyerName'] as String,
      phone: json['phone'] as String,
      lines: [
        for (final line in json['lines'] as List<dynamic>)
          BookingLine(
            ticketType: (line as Map<String, dynamic>)['ticketType'] as String,
            quantity: (line['quantity'] as num).toInt(),
          ),
      ],
      totalCents: (json['totalCents'] as num).toInt(),
      payment: PaymentMethod.values.byName(json['payment'] as String),
      channel: SalesChannel.values.byName(json['channel'] as String),
      status: BookingStatus.values.byName(json['status'] as String),
      promoCode: json['promoCode'] as String?,
      tshirtSizes: [for (final size in json['tshirtSizes'] as List<dynamic>) size as String],
      // Older servers send no seats.
      seats: [for (final seat in json['seats'] as List<dynamic>? ?? const []) seat as String],
      // `2026-11-28`: the day a place's tickets are for. Other bookings have none.
      visitDate: json['visitDate'] == null ? null : DateTime.parse(json['visitDate'] as String),
      checkIn: checkIn == null
          ? null
          : CheckIn(
              at: DateTime.parse(checkIn['at'] as String),
              staffName: checkIn['staffName'] as String,
            ),
      cancellation: cancellation == null
          ? null
          : Cancellation(
              at: DateTime.parse(cancellation['at'] as String),
              staffName: cancellation['staffName'] as String,
              // A reason this app does not know must not break the whole list.
              reason: CancelReason.values.asNameMap()[cancellation['reason']] ?? CancelReason.other,
              refundCents: (cancellation['refundCents'] as num).toInt(),
            ),
      runner: runner == null
          ? null
          : Runner(
              name: runner['name'] as String,
              phone: runner['phone'] as String,
              email: runner['email'] as String?,
              gender: runner['gender'] as String,
              age: (runner['age'] as num).toInt(),
              nationality: runner['nationality'] as String,
              emergencyName: runner['emergencyName'] as String,
              emergencyPhone: runner['emergencyPhone'] as String,
              shirtSize: runner['shirtSize'] as String,
            ),
    );
  }

  /// The body of `POST /merchant/bookings/{id}/cancel`.
  static Map<String, dynamic> cancelRequest(CancelReason reason) => {'reason': reason.name};

  /// The answer to `POST /merchant/checkins`.
  static CheckInResult checkInResult(Map<String, dynamic> json) {
    Booking withBooking() => booking(json['booking'] as Map<String, dynamic>);
    return switch (json['result']) {
      'admitted' => CheckInAdmitted(withBooking()),
      'alreadyUsed' => CheckInAlreadyUsed(withBooking()),
      'cancelled' => CheckInCancelled(withBooking()),
      'otherEvent' => CheckInOtherEvent(
        bookingId: json['bookingId'] as String,
        eventName: json['eventName'] as String,
        buyerName: json['buyerName'] as String?,
        summary: json['summary'] as String?,
      ),
      'notFound' => CheckInNotFound(json['bookingId'] as String),
      final other => throw FormatException('Unknown check-in result: $other'),
    };
  }

  /// The body of `POST /merchant/events/{id}/door-sales`. The phone number goes
  /// in E.164 form, `+85512345678`, whatever way it was typed.
  static Map<String, dynamic> doorSale(DoorSaleRequest request, {required String attemptId}) {
    return {
      'lines': [
        for (final line in request.lines) {'ticketType': line.ticketType, 'quantity': line.quantity},
      ],
      'buyerPhone': PhoneNumber.toE164(request.buyerPhone),
      'payment': request.payment.name,
      'attemptId': attemptId,
    };
  }
}
