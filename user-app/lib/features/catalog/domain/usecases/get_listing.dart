import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/listing.dart';
import '../repositories/catalog_repository.dart';

/// One listing, by its ID.
class GetListing implements UseCase<Listing, String> {
  const GetListing(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Result<Listing>> call(String id) => _repository.listing(id);
}
