part of 'bus_search_bloc.dart';

enum BusSearchStatus {
  /// The routes are loading.
  loading,

  /// The routes are known; the search can change.
  ready,

  /// The routes could not be loaded.
  failure,
}

enum DeparturesStatus { loading, loaded, failure }

final class BusSearchState extends Equatable {
  const BusSearchState({
    this.status = BusSearchStatus.loading,
    this.stops = const [],
    this.origin = '',
    this.destination = '',
    this.today,
    this.date,
    this.departuresStatus = DeparturesStatus.loading,
    this.departures = const [],
    this.errorMessage,
  });

  final BusSearchStatus status;

  /// Every place a bus leaves from or goes to, A to Z.
  final List<String> stops;
  final String origin;
  final String destination;
  final DateTime? today;

  /// The day searched; set once [status] is ready.
  final DateTime? date;
  final DeparturesStatus departuresStatus;
  final List<BusDeparture> departures;
  final String? errorMessage;

  /// What is being searched, or null before the routes are known.
  BusSearch? get search {
    final day = date;
    return day == null ? null : BusSearch(origin: origin, destination: destination, date: day);
  }

  BusSearchState copyWith({
    BusSearchStatus? status,
    List<String>? stops,
    String? origin,
    String? destination,
    DateTime? today,
    DateTime? date,
    DeparturesStatus? departuresStatus,
    List<BusDeparture>? departures,
    String? errorMessage,
  }) {
    return BusSearchState(
      status: status ?? this.status,
      stops: stops ?? this.stops,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      today: today ?? this.today,
      date: date ?? this.date,
      departuresStatus: departuresStatus ?? this.departuresStatus,
      departures: departures ?? this.departures,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    stops,
    origin,
    destination,
    today,
    date,
    departuresStatus,
    departures,
    errorMessage,
  ];
}
