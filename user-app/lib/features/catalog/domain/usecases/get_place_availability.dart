import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/place_availability.dart';
import '../repositories/catalog_repository.dart';

/// What is left of each kind of ticket of a place on a day.
class GetPlaceAvailability implements UseCase<PlaceAvailability, PlaceDayQuery> {
  const GetPlaceAvailability(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Result<PlaceAvailability>> call(PlaceDayQuery query) {
    return _repository.placeAvailability(placeId: query.placeId, date: query.day);
  }
}

class PlaceDayQuery extends Equatable {
  const PlaceDayQuery({required this.placeId, required this.day});

  final String placeId;

  /// Only the day counts.
  final DateTime day;

  @override
  List<Object?> get props => [placeId, day];
}
