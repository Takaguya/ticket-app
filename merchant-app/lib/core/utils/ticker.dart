/// Emits the seconds remaining, once per second, ending at 0.
///
/// Injected into blocs so tests can replace the real clock.
class Ticker {
  const Ticker();

  Stream<int> countdown({required int from}) {
    return Stream<int>.periodic(
      const Duration(seconds: 1),
      (elapsed) => from - elapsed - 1,
    ).take(from);
  }
}
