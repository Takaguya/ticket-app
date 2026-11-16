import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/showtime.dart';
import '../repositories/catalog_repository.dart';

/// Where and when a film shows on a day.
class GetShowtimes implements UseCase<List<TheatreShowtimes>, ShowtimesQuery> {
  const GetShowtimes(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Result<List<TheatreShowtimes>>> call(ShowtimesQuery query) {
    return _repository.showtimes(filmId: query.filmId, date: query.date);
  }
}

class ShowtimesQuery extends Equatable {
  const ShowtimesQuery({required this.filmId, required this.date});

  final String filmId;

  /// Only the day counts.
  final DateTime date;

  @override
  List<Object?> get props => [filmId, date];
}
