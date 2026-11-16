import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/network/polled_resource.dart';

/// Lets pending futures and stream events run.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  // Long enough that the timer never fires during a test; polls are started by hand.
  const never = Duration(hours: 1);

  test('the first watcher starts a fetch, and later watchers get the latest value at once', () async {
    var fetches = 0;
    final resource = PolledResource<int>(fetch: () async => ++fetches, interval: never);

    final first = <int>[];
    final firstWatch = resource.watch().listen(first.add);
    await settle();
    expect(first, [1]);

    final second = <int>[];
    final secondWatch = resource.watch().listen(second.add);
    await settle();
    expect(second, [1]);
    expect(fetches, 1);

    await resource.refresh();
    await settle();
    expect(first, [1, 2]);
    expect(second, [1, 2]);

    await firstWatch.cancel();
    await secondWatch.cancel();
  });

  test('an unchanged value is not sent again', () async {
    final resource = PolledResource<String>(fetch: () async => 'same', interval: never);
    final values = <String>[];
    final watch = resource.watch().listen(values.add);
    await settle();

    await resource.refresh();
    await settle();

    expect(values, ['same']);
    await watch.cancel();
  });

  test('a change the app made itself shows at once', () async {
    final resource = PolledResource<List<int>>(fetch: () async => [1, 2], interval: never);
    final values = <List<int>>[];
    final watch = resource.watch().listen(values.add);
    await settle();

    resource.update((current) => [...current, 3]);
    await settle();

    expect(values.last, [1, 2, 3]);
    await watch.cancel();
  });

  test('a poll that started before an update does not replace the newer value', () async {
    final answers = <Completer<List<int>>>[];
    final resource = PolledResource<List<int>>(
      fetch: () {
        final answer = Completer<List<int>>();
        answers.add(answer);
        return answer.future;
      },
      interval: never,
    );
    final values = <List<int>>[];
    final watch = resource.watch().listen(values.add);
    await settle();
    answers.first.complete([1, 2]);
    await settle();

    // A poll starts, then the app adds an item before the server answers.
    final poll = resource.refresh();
    resource.update((current) => [...current, 3]);
    answers.last.complete([1, 2]);
    await poll;
    await settle();

    expect(values.last, [1, 2, 3]);

    // The next poll, started after the update, is believed again.
    final next = resource.refresh();
    answers.last.complete([1, 2, 3, 4]);
    await next;
    await settle();
    expect(values.last, [1, 2, 3, 4]);
    await watch.cancel();
  });

  test('a failed poll is reported only while there is no value yet', () async {
    final answers = <Object>[StateError('offline'), 7, StateError('offline again')];
    final resource = PolledResource<int>(
      fetch: () async {
        final answer = answers.removeAt(0);
        if (answer is Error) throw answer;
        return answer as int;
      },
      interval: never,
    );
    final values = <int>[];
    final errors = <Object>[];
    final watch = resource.watch().listen(values.add, onError: errors.add);
    await settle();
    expect(errors, hasLength(1));

    await resource.refresh();
    await resource.refresh();
    await settle();

    expect(values, [7]);
    expect(errors, hasLength(1));
    await watch.cancel();
  });

  test('the value is forgotten when the last watcher leaves', () async {
    var fetches = 0;
    final resource = PolledResource<int>(fetch: () async => ++fetches, interval: never);
    final firstWatch = resource.watch().listen((_) {});
    await settle();
    await firstWatch.cancel();

    // As after signing out and in again: nothing from before, a fresh fetch.
    final values = <int>[];
    final secondWatch = resource.watch().listen(values.add);
    await settle();

    expect(values, [2]);
    await secondWatch.cancel();
  });

  test('an answer that arrives after everyone left is dropped', () async {
    final answers = <Completer<int>>[];
    final resource = PolledResource<int>(
      fetch: () {
        final answer = Completer<int>();
        answers.add(answer);
        return answer.future;
      },
      interval: never,
    );
    final watch = resource.watch().listen((_) {});
    await settle();
    await watch.cancel();

    // The old account's answer comes in late.
    answers.first.complete(1);
    await settle();

    final values = <int>[];
    final next = resource.watch().listen(values.add);
    await settle();
    expect(values, isEmpty);

    answers.last.complete(2);
    await settle();
    expect(values, [2]);
    await next.cancel();
  });
}
