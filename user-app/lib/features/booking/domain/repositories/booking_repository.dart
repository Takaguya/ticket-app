import '../../../../core/result/result.dart';
import '../../../catalog/domain/entities/bus_departure.dart';
import '../../../catalog/domain/entities/showtime.dart';
import '../entities/booking.dart';
import '../entities/order.dart';
import '../entities/promotion.dart';
import '../entities/runner_details.dart';
import '../entities/seat_map.dart';
import '../entities/snack.dart';

/// Seats, snacks, promo codes, paying, and the signed-in person's bookings.
abstract interface class BookingRepository {
  /// The bus's seats and which are taken.
  Future<Result<SeatMap>> busSeats(BusDeparture departure);

  /// The hall's seats for this screening and which are taken.
  Future<Result<SeatMap>> cinemaSeats(Showtime showtime);

  /// What the cinema sells at its counter.
  Future<Result<List<Snack>>> snacks({required String theatreId});

  /// The promo codes on offer now.
  Future<Result<List<Promotion>>> promotions();

  /// The runner details saved to the account, or null.
  Future<Result<RunnerDetails?>> savedRunner();

  /// Pays and issues the tickets. Fails with a reason when, for example, a
  /// seat has just been sold or the bus has left.
  Future<Result<Booking>> placeOrder(Order order);

  /// The person's bookings, soonest first, then again after every change.
  Stream<Result<List<Booking>>> watchBookings();

  Future<Result<Booking>> booking(String id);
}
