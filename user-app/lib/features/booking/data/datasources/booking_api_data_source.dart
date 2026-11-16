import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../catalog/data/models/bus_json.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/runner_details.dart';
import '../../domain/entities/seat_map.dart';
import '../models/booking_json.dart';

/// The buyer's booking endpoints of the Pin API. Throws `ApiException` or
/// `NetworkException`.
class BookingApiDataSource {
  const BookingApiDataSource(this._dio);

  final Dio _dio;

  /// `GET /buyer/promotions`
  Future<List<Promotion>> fetchPromotions() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/buyer/promotions');
      return [for (final json in response.data!) BookingJson.promotion(json as Map<String, dynamic>)];
    });
  }

  /// `GET /buyer/runner`: `{runner}`, with null when none is saved.
  Future<RunnerDetails?> fetchSavedRunner() {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/buyer/runner');
      final runner = response.data!['runner'] as Map<String, dynamic>?;
      return runner == null ? null : BookingJson.runner(runner);
    });
  }

  /// `POST /buyer/bookings` for an event order, a bus or cinema order (the
  /// seats chosen) or a place order (the day chosen). The server prices it,
  /// checks it and never sells the last ticket, seat or day's limit twice; a
  /// refusal is a 400 or 409 with a message for the person.
  Future<Booking> placeOrder(Order order, BookingRequest request) {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/buyer/bookings',
        data: switch (request) {
          EventRequest() => BookingJson.order(order, request),
          BusRequest() => BookingJson.busOrder(order, request),
          CinemaRequest() => BookingJson.cinemaOrder(order, request),
          AdmissionRequest() => BookingJson.admissionOrder(order, request),
        },
      );
      return BookingJson.booking(response.data!);
    });
  }

  /// `GET /catalog/cinema/showtimes/{id}/seats`: the hall's seats and which are
  /// taken, in the same shape as a bus's.
  Future<SeatMap> fetchCinemaSeats(String showtimeId) {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/catalog/cinema/showtimes/${Uri.encodeComponent(showtimeId)}/seats',
      );
      // A hall has a screen in front of its first row.
      return BusJson.seatMap(response.data!, hasScreen: true);
    });
  }

  /// `GET /catalog/bus/departures/{id}/seats`: the trip's seats and which are
  /// taken.
  Future<SeatMap> fetchBusSeats(String departureId) {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/catalog/bus/departures/${Uri.encodeComponent(departureId)}/seats',
      );
      return BusJson.seatMap(response.data!);
    });
  }

  /// `GET /buyer/bookings`
  Future<List<Booking>> fetchBookings() {
    return apiCall(() async {
      final response = await _dio.get<List<dynamic>>('/buyer/bookings');
      return [for (final json in response.data!) BookingJson.booking(json as Map<String, dynamic>)];
    });
  }

  /// `GET /buyer/bookings/{id}`; 404 when unknown or another buyer's.
  Future<Booking> fetchBooking(String id) {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/buyer/bookings/${Uri.encodeComponent(id)}');
      return BookingJson.booking(response.data!);
    });
  }
}
