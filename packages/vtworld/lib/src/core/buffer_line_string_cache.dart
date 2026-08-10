import 'dart:async';

import 'package:vtworld/src/core/disposable.dart';

/// Cancels a pending cache timer.
typedef BufferLineStringCacheTimerCancel = void Function();

/// Creates a cache timer for [delay].
typedef BufferLineStringCacheTimerFactory =
    BufferLineStringCacheTimerCancel Function(
      Duration delay,
      void Function() callback,
    );

BufferLineStringCacheTimerCancel _createDartCacheTimer(
  Duration delay,
  void Function() callback,
) {
  final timer = Timer(delay, callback);
  return timer.cancel;
}

/// Cached canonical string translation for one buffer line.
final class BufferLineStringCacheEntry {
  /// Creates an empty entry for [generation].
  BufferLineStringCacheEntry(this.generation);

  /// Cached translated value.
  String? value;

  /// Whether [value] was produced with right trimming.
  bool isTrimmed = false;

  /// Cache generation that owns this entry.
  final int generation;

  /// Stores a translated [text] and whether it was right-trimmed.
  void setValue(String text, {required bool isTrimmed}) {
    value = text;
    this.isTrimmed = isTrimmed;
  }
}

/// Shared short-lived cache used by all lines in one terminal buffer.
final class BufferLineStringCache implements Disposable {
  /// Creates a cache using the platform clock and timer by default.
  BufferLineStringCache({
    int Function()? now,
    BufferLineStringCacheTimerFactory? createTimer,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       _createTimer = createTimer ?? _createDartCacheTimer;

  /// Time after the last access before cached translations are discarded.
  static const int cacheTtlMilliseconds = 15000;

  /// Generation used to invalidate weak line references after [clear].
  int generation = 0;

  /// Entries retained until the cache expires or is cleared.
  final Set<BufferLineStringCacheEntry> entries =
      <BufferLineStringCacheEntry>{};

  final int Function() _now;
  final BufferLineStringCacheTimerFactory _createTimer;
  BufferLineStringCacheTimerCancel? _clearTimer;
  int _lastAccessTimestamp = 0;
  bool _isDisposed = false;

  /// Whether a cache expiry timer is pending.
  bool get hasPendingClear => _clearTimer != null;

  /// Refreshes the expiry deadline without allocating an entry.
  void touch() {
    if (_isDisposed) return;
    _scheduleClear();
  }

  /// Allocates and retains a new empty cache entry.
  BufferLineStringCacheEntry allocateEntry() {
    if (_isDisposed) throw StateError('String cache has been disposed');
    final entry = BufferLineStringCacheEntry(generation);
    entries.add(entry);
    _scheduleClear();
    return entry;
  }

  /// Invalidates all entries and cancels pending expiry work.
  void clear() {
    _clearTimer?.call();
    _clearTimer = null;
    _lastAccessTimestamp = 0;
    generation++;
    for (final entry in entries) {
      entry
        ..value = null
        ..isTrimmed = false;
    }
    entries.clear();
  }

  void _scheduleClear() {
    _lastAccessTimestamp = _now();
    if (_clearTimer != null) return;
    _scheduleClearTimeout(cacheTtlMilliseconds);
  }

  void _scheduleClearTimeout(int milliseconds) {
    _clearTimer = _createTimer(Duration(milliseconds: milliseconds), () {
      _clearTimer = null;
      final elapsed = _now() - _lastAccessTimestamp;
      if (elapsed >= cacheTtlMilliseconds) {
        clear();
        return;
      }
      _scheduleClearTimeout(cacheTtlMilliseconds - elapsed);
    });
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    clear();
    _isDisposed = true;
  }
}
