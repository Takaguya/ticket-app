import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/polled_resource.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/attempt_id.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/repositories/bookings_repository.dart';
import '../datasources/bookings_api_data_source.dart';

/// [BookingsRepository] answered by the Pin API.
///
/// The business's bookings are polled while a screen watches them, so check-ins
/// by other scanners and new online bookings show up within [pollEvery]. This
/// device's own check-ins and door sales show at once.
///
/// Lost answers: when a check-in or door sale gets no answer (no connection, or the
/// server stopped after saving it), trying the same thing again sends the same
/// attempt ID. The server then answers with what it already did, so a guest it
/// admitted is not refused as "already checked in" and a sale is not recorded twice.
class ApiBookingsRepository implements BookingsRepository {
  ApiBookingsRepository(
    this._api, {
    Duration pollEvery = const Duration(seconds: 10),
    String Function() attemptIds = newAttemptId,
  }) : _newAttemptId = attemptIds,
       _bookings = PolledResource(
         fetch: _api.fetchBookings,
         interval: pollEvery,
         equals: listEquals,
       );

  final BookingsApiDataSource _api;
  final String Function() _newAttemptId;
  final PolledResource<List<Booking>> _bookings;

  /// Scans that got no answer, by event and booking ID, with their attempt IDs.
  final Map<String, String> _unansweredScans = {};

  /// The last door sale that got no answer, with its attempt ID.
  (DoorSaleRequest, String)? _unansweredSale;

  @override
  Stream<List<Booking>> watchBookings() => _bookings.watch();

  @override
  Future<Result<CheckInResult>> checkIn({required String eventId, required String code}) {
    final key = '$eventId ${_normalized(code)}';
    final attempt = _unansweredScans[key] ??= _newAttemptId();
    return guard(() async {
      final result = await _keepAttemptIfUnanswered(
        () => _api.checkIn(eventId: eventId, code: code, attemptId: attempt),
        answered: () => _unansweredScans.remove(key),
      );
      // Every answer that carries the booking has its latest state, even when
      // another scanner changed it.
      final booking = switch (result) {
        CheckInAdmitted(:final booking) ||
        CheckInAlreadyUsed(:final booking) ||
        CheckInCancelled(:final booking) => booking,
        CheckInOtherEvent() || CheckInNotFound() => null,
      };
      if (booking != null) _bookings.update((bookings) => _withBooking(bookings, booking));
      return result;
    });
  }

  @override
  Future<Result<Booking>> sellAtDoor(DoorSaleRequest request) {
    final unanswered = _unansweredSale;
    // Only the very same sale tried again keeps its attempt; a changed cart is a new sale.
    final attempt = unanswered != null && unanswered.$1 == request ? unanswered.$2 : _newAttemptId();
    _unansweredSale = (request, attempt);
    return guard(() async {
      final booking = await _keepAttemptIfUnanswered(
        () => _api.sellAtDoor(request, attemptId: attempt),
        answered: () => _unansweredSale = null,
      );
      _bookings.update((bookings) => _withBooking(bookings, booking));
      return booking;
    });
  }

  @override
  Future<Result<Booking>> cancelBooking({required String bookingId, required CancelReason reason}) {
    return guard(() async {
      final booking = await _api.cancelBooking(bookingId, reason);
      _bookings.update((bookings) => _withBooking(bookings, booking));
      return booking;
    });
  }

  /// Runs [request]. A definite answer, success or refusal, calls [answered]. The
  /// attempt is kept for a retry when the outcome is unknown: no answer at all
  /// ([NetworkException]), or a server error (5xx), e.g. the database went down
  /// while saving.
  static Future<T> _keepAttemptIfUnanswered<T>(
    Future<T> Function() request, {
    required void Function() answered,
  }) async {
    try {
      final value = await request();
      answered();
      return value;
    } on NetworkException {
      rethrow;
    } on ApiException catch (error) {
      final outcomeUnknown = (error.statusCode ?? 500) >= 500;
      if (!outcomeUnknown) answered();
      rethrow;
    } on Object {
      answered();
      rethrow;
    }
  }

  /// `48213377`, `tk48213377` and ` TK48213377 ` are the same ticket.
  static String _normalized(String code) {
    final text = code.trim().toUpperCase();
    return RegExp(r'^\d+$').hasMatch(text) ? 'TK$text' : text;
  }

  /// [bookings] with [booking] replacing the one with its ID, or added first.
  static List<Booking> _withBooking(List<Booking> bookings, Booking booking) {
    final index = bookings.indexWhere((b) => b.id == booking.id);
    if (index < 0) return [booking, ...bookings];
    return [...bookings]..[index] = booking;
  }
}
