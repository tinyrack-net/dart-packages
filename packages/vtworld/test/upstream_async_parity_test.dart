import 'dart:async';

import 'package:test/test.dart';
import 'package:vtworld/src/core/async.dart';

void main() {
  test(
    'timeout timers cancel, replace, and reject work after disposal',
    () async {
      final values = <String>[];
      final timer = TimeoutTimer()
        ..cancelAndSet(() => values.add('old'), 20)
        ..cancelAndSet(() => values.add('new'), 1)
        ..setIfNotSet(() => values.add('ignored'), 1);
      await terminalTimeout(10);
      expect(values, <String>['new']);
      timer.dispose();
      expect(() => timer.cancelAndSet(() {}, 0), throwsStateError);
      expect(() => timer.setIfNotSet(() {}, 0), throwsStateError);
    },
  );

  test('microtask timer deduplicates and honors cancellation', () async {
    final values = <String>[];
    final timer = MicrotaskTimer()
      ..set(() => values.add('first'))
      ..set(() => values.add('duplicate'));
    await Future<void>.delayed(Duration.zero);
    expect(values, <String>['first']);
    timer
      ..set(() => values.add('cancelled'))
      ..cancel();
    await Future<void>.delayed(Duration.zero);
    expect(values, <String>['first']);
    timer.dispose();
    expect(() => timer.set(() {}), throwsStateError);
  });

  test(
    'disposable timeout and interval expose cancellable lifetimes',
    () async {
      var calls = 0;
      final timeout = disposableTimeout(() => calls++, milliseconds: 20)
        ..dispose();
      await terminalTimeout(30);
      expect(calls, 0);
      expect(timeout.isDisposed, isTrue);

      final completed = Completer<void>();
      final interval = IntervalTimer()
        ..cancelAndSet(() {
          if (!completed.isCompleted) completed.complete();
        }, 1);
      await completed.future.timeout(const Duration(seconds: 1));
      interval.dispose();
      expect(interval.isDisposed, isTrue);
      expect(() => interval.cancelAndSet(() {}, 1), throwsStateError);
    },
  );
}
