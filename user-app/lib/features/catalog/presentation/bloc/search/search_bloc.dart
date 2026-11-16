import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/listing.dart';
import '../../../domain/usecases/search_listings.dart';

part 'search_event.dart';
part 'search_state.dart';

/// Search across events, routes, films and places as the person types.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({required this._searchListings}) : super(const SearchState()) {
    on<SearchQueryChanged>(_onQueryChanged);
  }

  final SearchListings _searchListings;

  Future<void> _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }

    emit(SearchState(query: query, status: SearchStatus.searching, results: state.results));
    final result = await _searchListings(query);
    // Typing went on meanwhile: only the latest text counts.
    if (state.query != query) return;
    result.when(
      success: (results) => emit(SearchState(query: query, status: SearchStatus.done, results: results)),
      failure: (failure) => emit(
        SearchState(query: query, status: SearchStatus.failure, errorMessage: failure.message),
      ),
    );
  }
}
