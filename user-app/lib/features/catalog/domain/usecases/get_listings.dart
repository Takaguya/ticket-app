import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/listing.dart';
import '../entities/ticket_category.dart';
import '../repositories/catalog_repository.dart';

/// Everything on sale in a category, or in all of them when the category is null.
class GetListings implements UseCase<List<Listing>, TicketCategory?> {
  const GetListings(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Result<List<Listing>>> call(TicketCategory? category) {
    return _repository.listings(category: category);
  }
}
