/// A resource with an explicit lifetime.
abstract interface class Disposable {
  /// Whether [dispose] has already been called.
  bool get isDisposed;

  /// Releases the resource. Calling this more than once is harmless.
  void dispose();
}

/// A disposable backed by a callback.
final class CallbackDisposable implements Disposable {
  /// Creates a disposable that invokes [callback] on each disposal.
  CallbackDisposable(void Function() callback) : _callback = callback;

  final void Function() _callback;
  bool _isDisposed = false;

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    _callback();
  }
}

/// Creates the Dart equivalent of xterm.js' `toDisposable` helper.
Disposable toDisposable(void Function() callback) =>
    CallbackDisposable(callback);

/// Disposes every item in insertion order and returns an empty list.
List<T> disposeAll<T extends Disposable>(Iterable<T> disposables) {
  for (final disposable in disposables) {
    disposable.dispose();
  }
  return <T>[];
}

/// Combines several disposable lifetimes into one handle.
Disposable combinedDisposable(Iterable<Disposable> disposables) =>
    toDisposable(() => disposeAll(disposables));

/// Base class for resources that own other disposables.
abstract class DisposableStore implements Disposable {
  final Set<Disposable> _children = <Disposable>{};
  bool _isDisposed = false;

  @override
  bool get isDisposed => _isDisposed;

  /// Adds [child] to this object's lifetime.
  T add<T extends Disposable>(T child) {
    if (_isDisposed) {
      child.dispose();
      return child;
    }
    _children.add(child);
    return child;
  }

  /// Disposes and removes all current children without disposing this store.
  void clearDisposables() {
    for (final child in _children) {
      child.dispose();
    }
    _children.clear();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    clearDisposables();
  }
}

/// A replaceable disposable slot with xterm.js lifecycle semantics.
final class MutableDisposable<T extends Disposable> implements Disposable {
  T? _value;
  bool _isDisposed = false;

  /// The current value, or `null` after this slot is disposed.
  T? get value => _isDisposed ? null : _value;

  set value(T? next) {
    if (_isDisposed || identical(next, _value)) return;
    _value?.dispose();
    _value = next;
  }

  /// Disposes and removes the current value.
  void clear() => value = null;

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    _value?.dispose();
    _value = null;
  }
}
