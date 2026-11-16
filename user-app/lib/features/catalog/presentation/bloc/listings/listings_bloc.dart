import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/listing.dart';
import '../../../domain/entities/ticket_category.dart';
import '../../../domain/usecases/get_listings.dart';

part 'listings_event.dart';
part 'listings_state.dart';

/// Loads what is on sale in one category, or in all of them. Used by Home
/// (popular events), the Tickets page (everything) and each category's page.
class ListingsBloc extends Bloc<ListingsEvent, ListingsState> {
  ListingsBloc({required this._getListings, this.category}) : super(const ListingsState()) {
    on<ListingsRequested>(_onRequested);
  }

  final GetListings _getListings;

  /// Null loads every category.
  final TicketCategory? category;

  /// Loads again; completes when done. For pull to refresh.
  Future<void> refresh() {
    final done = Completer<void>();
    add(ListingsRequested(done: done));
    return done.future;
  }

  Future<void> _onRequested(ListingsRequested event, Emitter<ListingsState> emit) async {
    // A retry shows the spinner again; a refresh keeps the list on screen.
    if (state.status != ListingsStatus.loaded) {
      emit(state.copyWith(status: ListingsStatus.loading));
    }
    final result = await _getListings(category);
    result.when(
      success: (listings) => emit(ListingsState(status: ListingsStatus.loaded, listings: listings)),
      failure: (failure) => emit(
        state.copyWith(
          // Keep showing what was loaded before; report the problem only when nothing is.
          status: state.listings.isEmpty ? ListingsStatus.failure : ListingsStatus.loaded,
          errorMessage: failure.message,
        ),
      ),
    );
    event.done?.complete();
  }
}
