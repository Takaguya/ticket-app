import '../../../../core/utils/combine_latest.dart';
import '../../../bookings/domain/repositories/bookings_repository.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../entities/business_snapshot.dart';

/// Reads the current time. Replaced in tests.
typedef Clock = DateTime Function();

/// Follows the business's events and bookings together, so every screen
/// works from one consistent picture that updates as bookings arrive, are
/// cancelled or are checked in.
class WatchBusinessSnapshot {
  const WatchBusinessSnapshot({
    required this._events,
    required this._bookings,
    this._clock = DateTime.now,
  });

  final EventsRepository _events;
  final BookingsRepository _bookings;
  final Clock _clock;

  Stream<BusinessSnapshot> call() {
    return combineLatest2(
      _events.watchEvents(),
      _bookings.watchBookings(),
      (events, bookings) => BusinessSnapshot(events: events, bookings: bookings, asOf: _clock()),
    );
  }
}
