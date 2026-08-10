import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('Emitter', () {
    test('should fire with 0 listeners without error', () {
      final emitter = TerminalEventEmitter<int>();
      addTearDown(emitter.dispose);
      emitter.fire(42);
    });

    test('should fire with 1 listener', () {
      final emitter = TerminalEventEmitter<int>();
      addTearDown(emitter.dispose);
      int? received;
      emitter.event.listen((value) => received = value);
      emitter.fire(42);
      expect(received, 42);
    });

    test('should fire with 1 listener using thisArgs', () {
      final emitter = TerminalEventEmitter<int>();
      final receiver = _Receiver();
      addTearDown(emitter.dispose);
      emitter.event.listen(receiver.handle);
      emitter.fire(42);
      expect(receiver.value, 42);
    });

    test('should fire with multiple listeners', () {
      final emitter = TerminalEventEmitter<int>();
      final results = <int>[];
      addTearDown(emitter.dispose);
      emitter.event
        ..listen(results.add)
        ..listen((value) => results.add(value * 2))
        ..listen((value) => results.add(value * 3));
      emitter.fire(10);
      expect(results, <int>[10, 20, 30]);
    });

    test('should handle listener removal during fire', () {
      final emitter = TerminalEventEmitter<int>();
      final results = <String>[];
      addTearDown(emitter.dispose);
      late Disposable second;
      emitter.event.listen((_) => results.add('first'));
      second = emitter.event.listen((_) {
        results.add('second');
        second.dispose();
      });
      emitter.event.listen((_) => results.add('third'));
      emitter.fire(1);
      expect(results, <String>['first', 'second', 'third']);
    });

    test('should not fire after dispose', () {
      final emitter = TerminalEventEmitter<int>();
      var called = false;
      emitter.event.listen((_) => called = true);
      emitter
        ..dispose()
        ..fire(42);
      expect(called, isFalse);
    });

    test('should allow disposing a listener', () {
      final emitter = TerminalEventEmitter<int>();
      var count = 0;
      addTearDown(emitter.dispose);
      final listener = emitter.event.listen((_) => count++);
      emitter.fire(1);
      listener.dispose();
      emitter.fire(2);
      expect(count, 1);
    });
  });

  test('disposable stores preserve xterm lifecycle semantics', () {
    final calls = <String>[];
    final store = _Store();
    final child = CallbackDisposable(() => calls.add('child'));
    store
      ..add(child)
      ..add(child)
      ..dispose()
      ..dispose();
    expect((store.isDisposed, child.isDisposed), (true, true));
    expect(calls, <String>['child']);

    final lateChild = CallbackDisposable(() => calls.add('late'));
    expect(store.add(lateChild), same(lateChild));
    expect(lateChild.isDisposed, isTrue);
    expect(calls, <String>['child', 'late']);
  });

  test('mutable and combined disposables match xterm replacement rules', () {
    final calls = <String>[];
    final first = toDisposable(() => calls.add('first'));
    final second = toDisposable(() => calls.add('second'));
    final slot = MutableDisposable<Disposable>()
      ..value = first
      ..value = first
      ..value = second;
    expect(calls, <String>['first']);
    slot.clear();
    expect(calls, <String>['first', 'second']);

    combinedDisposable(<Disposable>[
      toDisposable(() => calls.add('a')),
      toDisposable(() => calls.add('b')),
    ]).dispose();
    expect(calls, <String>['first', 'second', 'a', 'b']);
  });

  test('event disposal rejects listeners and suppresses later delivery', () {
    final emitter = TerminalEventEmitter<int>();
    final values = <int>[];
    final listener = emitter.event.listen(values.add);
    emitter.fire(1);
    listener.dispose();
    emitter
      ..fire(2)
      ..dispose()
      ..dispose()
      ..fire(3);

    expect(values, <int>[1]);
    expect(emitter.isDisposed, isTrue);
    expect(() => emitter.event.listen(values.add), throwsStateError);
  });
}

final class _Store extends DisposableStore {}

final class _Receiver {
  int value = 0;

  int handle(int next) => value = next;
}
