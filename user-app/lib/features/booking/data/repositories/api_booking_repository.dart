import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/polled_resource.dart';
import '../../../../core/result/result.dart';
import '../../../catalog/domain/entities/bus_departure.dart';
import '../../../catalog/domain/entities/showtime.dart';
import '../../../catalog/domain/entities/ticket_category.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/runner_details.dart';
import '../../domain/entities/seat_map.dart';
import '../../domain/entities/snack.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_api_data_source.dart';

/// [BookingRepository] answered by the Pin API, for events, bus trips, cinema
/// screenings and places.
///
/// The bookings are polled every [pollEvery] while a screen watches them, so a
/// booking the business cancelled or scanned shows up by itself. A booking
/// placed here shows at once.
///
/// The server sells no snacks yet: they fail with a "coming soon" message. The
/// app does not offer them, so people never reach these.
class ApiBookingRepository implements BookingRepository {
  ApiBookingRepository(this._api, {Duration pollEvery = const Duration(seconds: 15)})
    : _bookings = PolledResource(fetch: _api.fetchBookings, interval: pollEvery, equals: listEquals);

  final BookingApiDataSource _api;
  final PolledResource<List<Booking>> _bookings;

  /// "Bus tickets are coming soon." and so on: names what was asked for.
  static Future<Result<T>> _comingSoon<T>(TicketCategory category) {
    return Future.value(Result.failure(RejectedFailure('${category.title} tickets are coming soon.')));
  }

  @override
  Future<Result<SeatMap>> busSeats(BusDeparture departure) => guard(() => _api.fetchBusSeats(departure.id));

  @override
  Future<Result<SeatMap>> cinemaSeats(Showtime showtime) => guard(() => _api.fetchCinemaSeats(showtime.id));

  @override
  Future<Result<List<Snack>>> snacks({required String theatreId}) => _comingSoon(TicketCategory.cinema);

  @override
  Future<Result<List<Promotion>>> promotions() => guard(_api.fetchPromotions);

  @override
  Future<Result<RunnerDetails?>> savedRunner() => guard(_api.fetchSavedRunner);

  @override
  Future<Result<Booking>> placeOrder(Order order) {
    final request = order.request;
    // Snacks are not sold by the server: refuse rather than take money for them.
    if (request is CinemaRequest && request.snacks.values.any((quantity) => quantity > 0)) {
      return Future.value(const Result.failure(RejectedFailure('Snacks are coming soon.')));
    }
    return guard(() async {
      final booking = await _api.placeOrder(order, request);
      _bookings.update((bookings) => _withBooking(bookings, booking));
      return booking;
    });
  }

  @override
  Stream<Result<List<Booking>>> watchBookings() {
    return _bookings.watch().transform(
      StreamTransformer<List<Booking>, Result<List<Booking>>>.fromHandlers(
        handleData: (bookings, sink) => sink.add(Result.success(bookings)),
        handleError: (error, _, sink) => sink.add(Result.failure(failureOf(error))),
      ),
    );
  }

  @override
  Future<Result<Booking>> booking(String id) => guard(() => _api.fetchBooking(id));

  /// [bookings] with [booking] replacing the one with its ID, or added; the
  /// soonest event first, as the server lists them.
  static List<Booking> _withBooking(List<Booking> bookings, Booking booking) {
    return [
      for (final other in bookings)
        if (other.id != booking.id) other,
      booking,
    ]..sort((a, b) => a.request.startsAt.compareTo(b.request.startsAt));
  }
}
