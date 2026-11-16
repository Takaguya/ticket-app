part of 'seat_selection_bloc.dart';

enum SeatSelectionStatus { loading, ready, failure }

final class SeatSelectionState extends Equatable {
  const SeatSelectionState({
    required this.request,
    this.status = SeatSelectionStatus.loading,
    this.seatMap,
    this.selected = const [],
    this.errorMessage,
    this.notice,
  });

  /// A [BusRequest] or a [CinemaRequest], without seats yet.
  final BookingRequest request;
  final SeatSelectionStatus status;

  /// Set once loaded.
  final SeatMap? seatMap;

  /// The chosen seats, in the order they were tapped.
  final List<Seat> selected;

  /// Why the seats could not be loaded.
  final String? errorMessage;

  /// A one-off message, e.g. that no more seats fit in one booking.
  final String? notice;

  bool isSelected(Seat seat) => selected.any((chosen) => chosen.id == seat.id);

  /// The request with the chosen seats, or null while none are chosen.
  BookingRequest? get chosen {
    if (selected.isEmpty) return null;
    return switch (request) {
      final BusRequest bus => bus.withSeats(selected),
      final CinemaRequest cinema => cinema.withSeats(selected),
      EventRequest() || AdmissionRequest() => null,
    };
  }

  int get totalCents => chosen?.subtotalCents ?? 0;

  /// Nullable fields that can be cleared take a function.
  SeatSelectionState copyWith({
    SeatSelectionStatus? status,
    SeatMap? seatMap,
    List<Seat>? selected,
    String? errorMessage,
    String? Function()? notice,
  }) {
    return SeatSelectionState(
      request: request,
      status: status ?? this.status,
      seatMap: seatMap ?? this.seatMap,
      selected: selected ?? this.selected,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [request, status, seatMap, selected, errorMessage, notice];
}
