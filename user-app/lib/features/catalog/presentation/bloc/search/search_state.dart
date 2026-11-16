part of 'search_bloc.dart';

enum SearchStatus {
  /// Nothing typed yet.
  idle,
  searching,
  done,
  failure,
}

final class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const [],
    this.errorMessage,
  });

  final String query;
  final SearchStatus status;

  /// While searching, the previous results stay until the new ones arrive.
  final List<Listing> results;
  final String? errorMessage;

  @override
  List<Object?> get props => [query, status, results, errorMessage];
}
