import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/booking.dart';
import '../repositories/bookings_repository.dart';

/// The owner cancels a whole booking, saying why.
class CancelBooking implements UseCase<Booking, CancelBookingParams> {
  const CancelBooking(this._repository);

  final BookingsRepository _repository;

  @override
  Future<Result<Booking>> call(CancelBookingParams params) {
    return _repository.cancelBooking(bookingId: params.bookingId, reason: params.reason);
  }
}

class CancelBookingParams extends Equatable {
  const CancelBookingParams({required this.bookingId, required this.reason});

  final String bookingId;
  final CancelReason reason;

  @override
  List<Object?> get props => [bookingId, reason];
}
