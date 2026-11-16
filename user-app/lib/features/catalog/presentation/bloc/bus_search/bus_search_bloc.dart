import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/result/result.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../domain/entities/bus_departure.dart';
import '../../../domain/entities/listing.dart';
import '../../../domain/entities/ticket_category.dart';
import '../../../domain/usecases/find_bus_departures.dart';
import '../../../domain/usecases/get_listings.dart';

part 'bus_search_event.dart';
part 'bus_search_state.dart';

/// "Bus tickets": choose where from, where to and the day, and see the buses.
class BusSearchBloc extends Bloc<BusSearchEvent, BusSearchState> {
  BusSearchBloc({
    required this._getListings,
    required this._findDepartures,
    required this._clock,
    this.initialRouteId,
  }) : super(const BusSearchState()) {
    on<BusSearchStarted>(_onStarted);
    on<BusOriginChosen>((event, emit) => _changeRoute(emit, origin: event.place));
    on<BusDestinationChosen>((event, emit) => _changeRoute(emit, destination: event.place));
    on<BusDirectionSwapped>(
      (event, emit) => _search(emit, state.copyWith(origin: state.destination, destination: state.origin)),
    );
    on<BusDateChosen>(
      (event, emit) => _search(emit, state.copyWith(date: DateFormat.dateOnly(event.date))),
    );
  }

  final GetListings _getListings;
  final FindBusDepartures _findDepartures;
  final Clock _clock;

  /// The route to start with, e.g. the one tapped on the Tickets page.
  final String? initialRouteId;

  Future<void> _onStarted(BusSearchStarted event, Emitter<BusSearchState> emit) async {
    emit(state.copyWith(status: BusSearchStatus.loading));
    switch (await _getListings(TicketCategory.bus)) {
      case FailureResult(:final failure):
        emit(state.copyWith(status: BusSearchStatus.failure, errorMessage: failure.message));
      case Success(value: final listings):
        final routes = listings.whereType<BusRoute>().toList();
        if (routes.isEmpty) {
          emit(state.copyWith(status: BusSearchStatus.failure, errorMessage: 'No bus routes yet.'));
          return;
        }
        final start = routes.firstWhere(
          (route) => route.id == initialRouteId,
          orElse: () => routes.first,
        );
        final stops = {for (final r in routes) ...[r.origin, r.destination]}.toList()..sort();
        final today = DateFormat.dateOnly(_clock.now());
        await _search(
          emit,
          state.copyWith(
            status: BusSearchStatus.ready,
            stops: stops,
            origin: start.origin,
            destination: start.destination,
            today: today,
            date: today,
          ),
        );
    }
  }

  /// A new place at one end. Choosing the place already at the other end
  /// swaps the two.
  Future<void> _changeRoute(Emitter<BusSearchState> emit, {String? origin, String? destination}) {
    var next = state.copyWith(origin: origin, destination: destination);
    if (next.origin == next.destination) {
      next = origin != null
          ? next.copyWith(destination: state.origin)
          : next.copyWith(origin: state.destination);
    }
    return _search(emit, next);
  }

  Future<void> _search(Emitter<BusSearchState> emit, BusSearchState next) async {
    emit(next.copyWith(departuresStatus: DeparturesStatus.loading, departures: const []));
    final search = BusSearch(origin: next.origin, destination: next.destination, date: next.date!);
    final result = await _findDepartures(search);
    // The person may have changed the search meanwhile: only the latest counts.
    if (state.search != search) return;
    result.when(
      success: (departures) => emit(
        state.copyWith(departuresStatus: DeparturesStatus.loaded, departures: departures),
      ),
      failure: (failure) => emit(
        state.copyWith(departuresStatus: DeparturesStatus.failure, errorMessage: failure.message),
      ),
    );
  }
}
