part of 'select_tickets_bloc.dart';

final class SelectTicketsState extends Equatable {
  const SelectTicketsState({
    required this.listing,
    this.quantities = const {},
    this.days = const [],
    this.day,
    this.availability = PlaceAvailability.unlimited,
    this.notice,
  });

  /// An [EventListing] or an [AdmissionListing].
  final Listing listing;

  /// How many of each kind are chosen.
  final Map<TicketTier, int> quantities;

  /// A place: the days it can be visited, today first.
  final List<DateTime> days;

  /// A place: the day of the visit.
  final DateTime? day;

  /// A place: what is left of each limited kind of ticket on [day]. Kinds with
  /// no limit are not listed, and nothing is limited until the answer comes.
  final PlaceAvailability availability;

  /// A one-off message, e.g. that no more tickets fit in one booking.
  final String? notice;

  List<TicketTier> get tiers => switch (listing) {
    EventListing(:final tiers) || AdmissionListing(:final tiers) => tiers,
    FilmListing() || BusRoute() => const [],
  };

  int quantityOf(TicketTier tier) => quantities[tier] ?? 0;

  int get ticketCount => quantities.values.fold(0, (sum, quantity) => sum + quantity);

  /// What to pay for, or null while nothing is chosen.
  BookingRequest? get request {
    if (ticketCount == 0) return null;
    return switch (listing) {
      final EventListing event => EventRequest(event: event, quantities: quantities),
      final AdmissionListing place => AdmissionRequest(
        attraction: place,
        day: day!,
        quantities: quantities,
      ),
      FilmListing() || BusRoute() => null,
    };
  }

  int get totalCents => request?.subtotalCents ?? 0;

  /// [notice] takes a function so it can be cleared.
  SelectTicketsState copyWith({
    Map<TicketTier, int>? quantities,
    DateTime? day,
    PlaceAvailability? availability,
    String? Function()? notice,
  }) {
    return SelectTicketsState(
      listing: listing,
      quantities: quantities ?? this.quantities,
      days: days,
      day: day ?? this.day,
      availability: availability ?? this.availability,
      notice: notice == null ? this.notice : notice(),
    );
  }

  @override
  List<Object?> get props => [listing, quantities, days, day, availability, notice];
}
