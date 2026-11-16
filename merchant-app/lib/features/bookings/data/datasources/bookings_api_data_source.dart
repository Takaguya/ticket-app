import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/repositories/bookings_repository.dart';
import '../models/booking_json.dart';

/// The booking endpoints of the Pin API. Throws `ApiException` or
/// `NetworkException`.
class BookingsApiDataSource {
  const BookingsApiDataSource(this._dio);

  final Dio _dio;

  /// `GET /merchant/bookings`: every booking of the business.
  Future<List<Booking>> fetchBookings() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/merchant/bookings');
      return [for (final json in response.data!) BookingJson.booking(json as Map<String, dynamic>)];
    });
  }

  /// `POST /merchant/checkins`. The server decides in one step, with the
  /// booking locked, so two scanners never both admit it. [attemptId] names this
  /// scan; send the same one when retrying after a lost answer.
  Future<CheckInResult> checkIn({
    required String eventId,
    required String code,
    required String attemptId,
  }) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/checkins',
        data: {'eventId': eventId, 'code': code, 'attemptId': attemptId},
      );
      return BookingJson.checkInResult(response.data!);
    });
  }

  /// `POST /merchant/events/{id}/door-sales`. Owner only. [attemptId] names this
  /// sale; send the same one when retrying after a lost answer.
  Future<Booking> sellAtDoor(DoorSaleRequest request, {required String attemptId}) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/events/${request.eventId}/door-sales',
        data: BookingJson.doorSale(request, attemptId: attemptId),
      );
      return BookingJson.booking(response.data!);
    });
  }

  /// `POST /merchant/bookings/{id}/cancel`. Owner only. The server refuses with
  /// 409 when the booking is checked in or its event has ended.
  Future<Booking> cancelBooking(String bookingId, CancelReason reason) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/merchant/bookings/$bookingId/cancel',
        data: BookingJson.cancelRequest(reason),
      );
      return BookingJson.booking(response.data!);
    });
  }
}
