import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../catalog/domain/entities/bus_departure.dart';
import '../../../catalog/domain/entities/showtime.dart';
import '../entities/seat_map.dart';
import '../repositories/booking_repository.dart';

/// The seats of a bus or a screening, and which are already taken.
class GetSeatMap implements UseCase<SeatMap, SeatsOf> {
  const GetSeatMap(this._repository);

  final BookingRepository _repository;

  @override
  Future<Result<SeatMap>> call(SeatsOf of) {
    return switch (of) {
      SeatsOfBus(:final departure) => _repository.busSeats(departure),
      SeatsOfShowtime(:final showtime) => _repository.cinemaSeats(showtime),
    };
  }
}

/// Whose seats to show.
sealed class SeatsOf {
  const SeatsOf();
}

final class SeatsOfBus extends SeatsOf {
  const SeatsOfBus(this.departure);

  final BusDeparture departure;
}

final class SeatsOfShowtime extends SeatsOf {
  const SeatsOfShowtime(this.showtime);

  final Showtime showtime;
}
