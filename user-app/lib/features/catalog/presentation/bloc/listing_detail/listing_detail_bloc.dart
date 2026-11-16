import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/result/result.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../domain/entities/listing.dart';
import '../../../domain/entities/showtime.dart';
import '../../../domain/usecases/get_listing.dart';
import '../../../domain/usecases/get_showtimes.dart';

part 'listing_detail_event.dart';
part 'listing_detail_state.dart';

/// One listing's page. For a film it also offers the next two weeks and the
/// showtimes of the chosen day.
class ListingDetailBloc extends Bloc<ListingDetailEvent, ListingDetailState> {
  ListingDetailBloc({
    required this._getListing,
    required this._getShowtimes,
    required this._clock,
    required this.listingId,
  }) : super(const ListingDetailState()) {
    on<ListingDetailStarted>(_onStarted);
    on<ListingDetailDayChosen>(_onDayChosen);
    on<ListingDetailShowtimeChosen>(
      (event, emit) => emit(state.copyWith(selectedShowtime: () => event.showtime)),
    );
  }

  /// How many days ahead a film's showtimes can be chosen, today included.
  static const filmDays = 14;

  final GetListing _getListing;
  final GetShowtimes _getShowtimes;
  final Clock _clock;
  final String listingId;

  Future<void> _onStarted(ListingDetailStarted event, Emitter<ListingDetailState> emit) async {
    emit(state.copyWith(status: ListingDetailStatus.loading));
    switch (await _getListing(listingId)) {
      case FailureResult(:final failure):
        emit(state.copyWith(status: ListingDetailStatus.failure, errorMessage: failure.message));
      case Success(value: final listing):
        emit(state.copyWith(status: ListingDetailStatus.loaded, listing: listing));
        if (listing is FilmListing) {
          final today = DateFormat.dateOnly(_clock.now());
          emit(
            state.copyWith(
              today: today,
              days: [
                for (var i = 0; i < filmDays; i++) DateTime(today.year, today.month, today.day + i),
              ],
            ),
          );
          await _loadShowtimes(today, emit);
        }
    }
  }

  Future<void> _onDayChosen(ListingDetailDayChosen event, Emitter<ListingDetailState> emit) {
    return _loadShowtimes(DateFormat.dateOnly(event.day), emit);
  }

  Future<void> _loadShowtimes(DateTime day, Emitter<ListingDetailState> emit) async {
    emit(
      state.copyWith(
        selectedDay: day,
        theatres: const [],
        showtimesLoading: true,
        selectedShowtime: () => null,
        showtimesError: () => null,
      ),
    );
    final result = await _getShowtimes(ShowtimesQuery(filmId: listingId, date: day));
    // The person may have chosen another day meanwhile: that day's answer counts.
    if (state.selectedDay != day) return;
    result.when(
      success: (theatres) => emit(state.copyWith(theatres: theatres, showtimesLoading: false)),
      failure: (failure) => emit(
        state.copyWith(showtimesLoading: false, showtimesError: () => failure.message),
      ),
    );
  }
}
