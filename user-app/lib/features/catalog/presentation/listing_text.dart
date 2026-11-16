import '../../../core/utils/date_format.dart';
import '../../../core/utils/money.dart';
import '../domain/entities/listing.dart';

/// The short lines that describe a listing on cards and rows.
extension ListingText on Listing {
  /// When it can be used: "Sun 22 Nov 2026", "Any day" or "Daily".
  String get whenText => switch (this) {
    EventListing(:final startsAt) => DateFormat.long(startsAt),
    FilmListing() => 'Daily',
    AdmissionListing() || BusRoute() => 'Any day',
  };

  /// Where, or what kind: "Koh Pich Theatre", "Siem Reap" or "Khmer · 1h 52m".
  String get placeText => switch (this) {
    EventListing(:final venue) => venue,
    AdmissionListing(:final venue) => venue,
    BusRoute(:final destination) => destination,
    FilmListing(:final genre, :final runtime) => '$genre · ${DateFormat.duration(runtime)}',
  };

  /// "Sun 22 Nov 2026 · Koh Pich Theatre"
  String get summaryText => '$whenText · $placeText';

  /// "From $15.00", or "Free" when nothing costs anything.
  String get fromPriceText => fromPriceCents == 0 ? 'Free' : 'From ${Money.format(fromPriceCents)}';
}
