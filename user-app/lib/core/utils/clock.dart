/// The current time. Injected wherever "now" or "today" matters, so tests can
/// fix it.
class Clock {
  const Clock();

  DateTime now() => DateTime.now();
}

/// A clock stopped at [time], for tests.
class FixedClock implements Clock {
  const FixedClock(this.time);

  final DateTime time;

  @override
  DateTime now() => time;
}
