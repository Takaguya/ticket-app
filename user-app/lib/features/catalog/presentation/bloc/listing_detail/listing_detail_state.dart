part of 'listing_detail_bloc.dart';

enum ListingDetailStatus { loading, loaded, failure }

final class ListingDetailState extends Equatable {
  const ListingDetailState({
    this.status = ListingDetailStatus.loading,
    this.listing,
    this.errorMessage,
    this.today,
    this.days = const [],
    this.selectedDay,
    this.theatres = const [],
    this.showtimesLoading = false,
    this.showtimesError,
    this.selectedShowtime,
  });

  final ListingDetailStatus status;

  /// Set once loaded.
  final Listing? listing;

  /// Why the listing could not be loaded.
  final String? errorMessage;

  // Films only

  /// The first of [days].
  final DateTime? today;

  /// The days a showtime can be chosen on.
  final List<DateTime> days;
  final DateTime? selectedDay;

  /// The cinemas showing the film on [selectedDay].
  final List<TheatreShowtimes> theatres;
  final bool showtimesLoading;
  final String? showtimesError;
  final Showtime? selectedShowtime;

  /// Nullable fields that can be cleared take a function.
  ListingDetailState copyWith({
    ListingDetailStatus? status,
    Listing? listing,
    String? errorMessage,
    DateTime? today,
    List<DateTime>? days,
    DateTime? selectedDay,
    List<TheatreShowtimes>? theatres,
    bool? showtimesLoading,
    String? Function()? showtimesError,
    Showtime? Function()? selectedShowtime,
  }) {
    return ListingDetailState(
      status: status ?? this.status,
      listing: listing ?? this.listing,
      errorMessage: errorMessage ?? this.errorMessage,
      today: today ?? this.today,
      days: days ?? this.days,
      selectedDay: selectedDay ?? this.selectedDay,
      theatres: theatres ?? this.theatres,
      showtimesLoading: showtimesLoading ?? this.showtimesLoading,
      showtimesError: showtimesError == null ? this.showtimesError : showtimesError(),
      selectedShowtime: selectedShowtime == null ? this.selectedShowtime : selectedShowtime(),
    );
  }

  @override
  List<Object?> get props => [
    status,
    listing,
    errorMessage,
    today,
    days,
    selectedDay,
    theatres,
    showtimesLoading,
    showtimesError,
    selectedShowtime,
  ];
}
