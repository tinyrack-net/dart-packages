import 'package:vtworld/src/core/disposable.dart';

/// Listener for a synchronous terminal event.
typedef TerminalEventListener<T> = void Function(T value);

/// The read-only side of an xterm-compatible synchronous event.
final class TerminalEvent<T> {
  TerminalEvent._(this._emitter);

  final TerminalEventEmitter<T> _emitter;

  /// Registers [listener] and returns a handle that removes it.
  Disposable listen(TerminalEventListener<T> listener) =>
      _emitter._listen(listener);
}

/// Emits a [TerminalEvent] synchronously in registration order.
final class TerminalEventEmitter<T> implements Disposable {
  final List<TerminalEventListener<T>> _listeners =
      <TerminalEventListener<T>>[];
  bool _isDisposed = false;

  /// The public event surface.
  late final TerminalEvent<T> event = TerminalEvent<T>._(this);

  Disposable _listen(TerminalEventListener<T> listener) {
    if (_isDisposed) {
      throw StateError('Cannot listen to a disposed event');
    }
    _listeners.add(listener);
    return CallbackDisposable(() => _listeners.remove(listener));
  }

  /// Notifies a snapshot of current listeners.
  void fire(T value) {
    if (_isDisposed) return;
    for (final listener in List<TerminalEventListener<T>>.of(_listeners)) {
      listener(value);
    }
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _listeners.clear();
  }
}

/// Unit value used by events that carry no payload.
enum TerminalVoid {
  /// The only unit value.
  value,
}
