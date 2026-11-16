import 'dart:async';

/// A value kept in step with the server by asking for it again every
/// [interval]: what the merchant app does instead of a socket.
///
/// [watch] gives the latest value at once when there is one, then every new
/// value. Polling runs only while someone watches. When the last watcher
/// leaves (for example on sign-out) the value is forgotten, so nothing carries
/// over to the next account.
///
/// Changes the app makes itself are applied with [update], so screens show
/// them at once instead of after the next poll.
class PolledResource<T> {
  PolledResource({
    required this._fetch,
    this.interval = const Duration(seconds: 10),
    bool Function(T previous, T next)? equals,
  }) : _equals = equals ?? ((a, b) => a == b);

  final Future<T> Function() _fetch;
  final bool Function(T previous, T next) _equals;

  /// Time between polls.
  final Duration interval;

  late final StreamController<T> _changes = StreamController<T>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );
  Timer? _timer;
  T? _latest;
  var _hasValue = false;

  /// Bumped when watching stops and when the app applies a change itself, so
  /// an answer to a poll that started earlier is dropped: it may not include
  /// the change yet and would bring the old list back.
  var _generation = 0;

  /// The latest value first, if there is one, then each change.
  ///
  /// A failed poll is reported only while there is no value yet; after that
  /// the last value stays and the next poll tries again.
  Stream<T> watch() async* {
    if (_hasValue) yield _latest as T;
    yield* _changes.stream;
  }

  /// Asks the server now instead of waiting for the next poll.
  Future<void> refresh() => _poll();

  /// Applies a change the app made itself, e.g. a check-in it just did.
  /// Does nothing while nobody watches. A poll already under way is dropped;
  /// the next one carries the change.
  void update(T Function(T current) change) {
    if (!_hasValue) return;
    _generation++;
    _publish(change(_latest as T));
  }

  void _start() {
    unawaited(_poll());
    _timer = Timer.periodic(interval, (_) => unawaited(_poll()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    _latest = null;
    _hasValue = false;
  }

  Future<void> _poll() async {
    final generation = _generation;
    try {
      final value = await _fetch();
      if (generation == _generation && _changes.hasListener) _publish(value);
    } on Object catch (error, stackTrace) {
      if (generation == _generation && _changes.hasListener && !_hasValue) {
        _changes.addError(error, stackTrace);
      }
    }
  }

  void _publish(T value) {
    if (_hasValue && _equals(_latest as T, value)) return;
    _latest = value;
    _hasValue = true;
    _changes.add(value);
  }
}
