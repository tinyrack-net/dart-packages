import 'dart:async';

/// A deferred task that returns true when it needs another invocation.
typedef TerminalIdleTask = bool? Function();

/// Ordered deferred work with synchronous flush and cancellation support.
class PriorityTaskQueue {
  /// Creates a queue, optionally reporting deadline overruns through [warn].
  PriorityTaskQueue({this.warn});

  /// Receives warnings when work exceeds its allotted frame deadline.
  final void Function(String message)? warn;
  final List<TerminalIdleTask> _tasks = <TerminalIdleTask>[];
  Timer? _callback;
  int _index = 0;

  /// Adds [task] for a future callback.
  void enqueue(TerminalIdleTask task) {
    _tasks.add(task);
    _start();
  }

  /// Runs every remaining task synchronously.
  void flush() {
    while (_index < _tasks.length) {
      if (_tasks[_index]() != true) _index++;
    }
    clear();
  }

  /// Cancels and removes all remaining work.
  void clear() {
    _callback?.cancel();
    _callback = null;
    _index = 0;
    _tasks.clear();
  }

  void _start() {
    _callback ??= Timer(Duration.zero, _process);
  }

  void _process() {
    _callback = null;
    final frame = Stopwatch()..start();
    var longestTaskMicros = 0;
    var lastRemainingMicros = 16000;
    while (_index < _tasks.length) {
      final task = Stopwatch()..start();
      if (_tasks[_index]() != true) _index++;
      task.stop();
      final duration = task.elapsedMicroseconds < 1000
          ? 1000
          : task.elapsedMicroseconds;
      longestTaskMicros = duration > longestTaskMicros
          ? duration
          : longestTaskMicros;
      final remaining = 16000 - frame.elapsedMicroseconds;
      if (longestTaskMicros * 1.5 > remaining) {
        if (lastRemainingMicros - duration < -20000) {
          final exceeded = ((duration - lastRemainingMicros) / 1000).round();
          warn?.call('task queue exceeded allotted deadline by ${exceeded}ms');
        }
        _start();
        return;
      }
      lastRemainingMicros = remaining;
    }
    clear();
  }
}

/// Xterm's idle queue fallback. Dart schedules through the priority queue on
/// hosts without a DOM `requestIdleCallback` surface.
final class IdleTaskQueue extends PriorityTaskQueue {
  /// Creates an idle task queue.
  IdleTaskQueue({super.warn});
}

/// Holds only the most recently configured idle task.
final class DebouncedIdleTask {
  /// Creates a debounced task holder.
  DebouncedIdleTask({void Function(String message)? warn})
    : _queue = IdleTaskQueue(warn: warn);

  final IdleTaskQueue _queue;

  /// Replaces pending work with [task].
  void set(TerminalIdleTask task) {
    _queue
      ..clear()
      ..enqueue(task);
  }

  /// Runs pending work synchronously.
  void flush() => _queue.flush();

  /// Cancels pending work.
  void dispose() => _queue.clear();
}
