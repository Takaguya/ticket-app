import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/check_in_result.dart';
import '../repositories/bookings_repository.dart';

/// Checks a scanned or typed booking in, or says why it cannot be admitted.
class CheckInBooking implements UseCase<CheckInResult, CheckInParams> {
  const CheckInBooking(this._repository);

  final BookingsRepository _repository;

  @override
  Future<Result<CheckInResult>> call(CheckInParams params) {
    return _repository.checkIn(eventId: params.eventId, code: params.code.trim());
  }
}

class CheckInParams extends Equatable {
  const CheckInParams({required this.eventId, required this.code});

  /// The event being scanned for.
  final String eventId;

  /// QR payload, full booking ID, or just its 8 digits.
  final String code;

  @override
  List<Object?> get props => [eventId, code];
}
