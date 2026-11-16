import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/bus_departure.dart';
import '../repositories/catalog_repository.dart';

/// Buses between two places on a day.
class FindBusDepartures implements UseCase<List<BusDeparture>, BusSearch> {
  const FindBusDepartures(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Result<List<BusDeparture>>> call(BusSearch search) {
    return _repository.busDepartures(
      origin: search.origin,
      destination: search.destination,
      date: search.date,
    );
  }
}

/// Where from, where to and which day.
class BusSearch extends Equatable {
  const BusSearch({required this.origin, required this.destination, required this.date});

  final String origin;
  final String destination;

  /// Only the day counts.
  final DateTime date;

  @override
  List<Object?> get props => [origin, destination, date];
}
