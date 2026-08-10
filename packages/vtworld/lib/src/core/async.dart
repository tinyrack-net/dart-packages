import 'dart:async';

import 'package:vtworld/src/core/disposable.dart';

/// Completes after [milliseconds].
Future<void> terminalTimeout(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

/// Creates a cancellable one-shot timeout and optionally owns it in [store].
Disposable disposableTimeout(
  void Function() handler, {
  int milliseconds = 0,
  DisposableStore? store,
}) {
  late final Disposable disposable;
  final timer = Timer(Duration(milliseconds: milliseconds), () {
    handler();
    if (store != null) disposable.dispose();
  });
  disposable = toDisposable(timer.cancel);
  store?.add(disposable);
  return disposable;
}

/// A reusable cancellable one-shot timer.
final class TimeoutTimer implements Disposable {
  Timer? _token;
  bool _isDisposed = false;

  /// Cancels pending work.
  void cancel() {
    _token?.cancel();
    _token = null;
  }

  /// Cancels pending work and schedules [runner].
  void cancelAndSet(void Function() runner, int milliseconds) {
    if (_isDisposed) {
      throw StateError('Calling cancelAndSet on a disposed TimeoutTimer');
    }
    cancel();
    _token = Timer(Duration(milliseconds: milliseconds), () {
      _token = null;
      runner();
    });
  }

  /// Schedules [runner] only when no timer is pending.
  void setIfNotSet(void Function() runner, int milliseconds) {
    if (_isDisposed) {
      throw StateError('Calling setIfNotSet on a disposed TimeoutTimer');
    }
    if (_token != null) return;
    _token = Timer(Duration(milliseconds: milliseconds), () {
      _token = null;
      runner();
    });
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    cancel();
    _isDisposed = true;
  }
}

/// A deduplicated cancellable microtask timer.
final class MicrotaskTimer implements Disposable {
  bool _isScheduled = false;
  bool _isDisposed = false;

  /// Prevents a scheduled runner from executing.
  void cancel() => _isScheduled = false;

  /// Schedules [runner] once on the microtask queue.
  void set(void Function() runner) {
    if (_isDisposed) {
      throw StateError('Calling set on a disposed MicrotaskTimer');
    }
    if (_isScheduled) return;
    _isScheduled = true;
    scheduleMicrotask(() {
      if (!_isScheduled) return;
      _isScheduled = false;
      runner();
    });
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    cancel();
    _isDisposed = true;
  }
}

/// A reusable cancellable periodic timer.
final class IntervalTimer implements Disposable {
  Timer? _token;
  bool _isDisposed = false;

  /// Cancels the active interval.
  void cancel() {
    _token?.cancel();
    _token = null;
  }

  /// Replaces the active interval with [runner].
  void cancelAndSet(void Function() runner, int milliseconds) {
    if (_isDisposed) {
      throw StateError('Calling cancelAndSet on a disposed IntervalTimer');
    }
    cancel();
    _token = Timer.periodic(
      Duration(milliseconds: milliseconds),
      (_) => runner(),
    );
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    cancel();
    _isDisposed = true;
  }
}
