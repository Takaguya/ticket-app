import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../entities/booking.dart';
import '../entities/check_in_result.dart';

/// A sale made at the entrance.
class DoorSaleRequest extends Equatable {
  const DoorSaleRequest({
    required this.eventId,
    required this.lines,
    required this.buyerPhone,
    required this.payment,
  });

  final String eventId;
  final List<BookingLine> lines;
  final String buyerPhone;

  /// Cash or KHQR.
  final PaymentMethod payment;

  @override
  List<Object?> get props => [eventId, lines, buyerPhone, payment];
}

abstract interface class BookingsRepository {
  /// Every booking of the business: the current list first, then again after
  /// each new booking, cancellation or check-in.
  Stream<List<Booking>> watchBookings();

  /// Validates a scanned QR payload or a typed booking ID for [eventId] and,
  /// when it is valid, checks the whole booking in. The 8 digits alone are
  /// accepted; `TK` is added.
  Future<Result<CheckInResult>> checkIn({required String eventId, required String code});

  /// Records a door sale. Owner only. Fails when not enough tickets are left.
  Future<Result<Booking>> sellAtDoor(DoorSaleRequest request);

  /// Cancels a whole booking. Owner only. Refused when it is checked in or its
  /// event has ended; cancelling a cancelled booking answers it unchanged.
  Future<Result<Booking>> cancelBooking({required String bookingId, required CancelReason reason});
}
