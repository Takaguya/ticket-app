import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/listing.dart';
import '../repositories/catalog_repository.dart';

/// Listings whose name or place matches what the person typed. An empty
/// query finds nothing.
class SearchListings implements UseCase<List<Listing>, String> {
  const SearchListings(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Result<List<Listing>>> call(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Result.success([]);
    return _repository.search(trimmed);
  }
}
