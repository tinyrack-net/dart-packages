import 'dart:async';

import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';
import 'package:vtworld/src/core/marker.dart';
import 'package:vtworld/src/core/sorted_list.dart';

/// Per-logical-line decoration index matching xterm's line cache behavior.
final class DecorationLineCache extends DisposableStore {
  final Map<int, List<TerminalDecoration>> _decorationsByLine =
      <int, List<TerminalDecoration>>{};
  final Set<TerminalDecoration> _decorations = <TerminalDecoration>{};
  Disposable? _bufferListeners;
  int _syncGeneration = 0;

  /// Removes all indexed decorations and pending synchronization work.
  void clear() {
    _syncGeneration++;
    _decorationsByLine.clear();
    _decorations.clear();
  }

  /// Adds [decoration] to every logical line it spans.
  void addDecoration(TerminalDecoration decoration) {
    _decorations.add(decoration);
    _addToLineBuckets(decoration);
  }

  /// Removes [decoration] from the index.
  void removeDecoration(TerminalDecoration decoration) {
    _decorations.remove(decoration);
    _rebuild();
  }

  /// Decorations whose height spans [line], or `null` when none exist.
  List<TerminalDecoration>? getDecorationsOnLine(int line) {
    final bucket = _decorationsByLine[line];
    return bucket == null
        ? null
        : List<TerminalDecoration>.unmodifiable(bucket);
  }

  /// Observes structural changes on the currently active buffer.
  void attachToBuffer(TerminalBuffer buffer) {
    _bufferListeners?.dispose();
    final listeners = <Disposable>[
      buffer.onTrim.listen((_) => _rebuild()),
      buffer.onInsert.listen((_) => _scheduleRebuild()),
      buffer.onDelete.listen((_) => _scheduleRebuild()),
    ];
    _bufferListeners = combinedDisposable(listeners);
  }

  void _addToLineBuckets(TerminalDecoration decoration) {
    if (decoration.marker.isDisposed || decoration.marker.line < 0) return;
    for (
      var line = decoration.marker.line;
      line < decoration.marker.line + decoration.height;
      line++
    ) {
      (_decorationsByLine[line] ??= <TerminalDecoration>[]).add(decoration);
    }
  }

  void _scheduleRebuild() {
    final generation = ++_syncGeneration;
    scheduleMicrotask(() {
      if (isDisposed || generation != _syncGeneration) return;
      _rebuild();
    });
  }

  void _rebuild() {
    _decorationsByLine.clear();
    _decorations.forEach(_addToLineBuckets);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _syncGeneration++;
    _bufferListeners?.dispose();
    _bufferListeners = null;
    _decorationsByLine.clear();
    _decorations.clear();
    super.dispose();
  }
}

/// Owns marker-backed decorations and indexes them by logical buffer line.
final class DecorationService extends DisposableStore {
  /// Creates a service attached to the active buffer in [bufferNamespace].
  DecorationService(TerminalBufferNamespace bufferNamespace)
    : _buffers = bufferNamespace {
    _lineCache.attachToBuffer(_buffers.active);
    add(
      _buffers.onBufferActivate.listen((event) {
        _lineCache
          ..attachToBuffer(event.activeBuffer)
          .._rebuild();
      }),
    );
    add(_lineCache);
  }

  final TerminalBufferNamespace _buffers;
  final SortedList<TerminalDecoration> _decorations =
      SortedList<TerminalDecoration>((decoration) => decoration.marker.line);
  final DecorationLineCache _lineCache = DecorationLineCache();
  final TerminalEventEmitter<TerminalDecoration> _onDecorationRegistered =
      TerminalEventEmitter<TerminalDecoration>();
  final TerminalEventEmitter<TerminalDecoration> _onDecorationRemoved =
      TerminalEventEmitter<TerminalDecoration>();

  /// Fires synchronously after a decoration is registered.
  TerminalEvent<TerminalDecoration> get onDecorationRegistered =>
      _onDecorationRegistered.event;

  /// Fires synchronously after a decoration is removed.
  TerminalEvent<TerminalDecoration> get onDecorationRemoved =>
      _onDecorationRemoved.event;

  /// All live decorations sorted by their marker line.
  Iterable<TerminalDecoration> get decorations => _decorations.values();

  /// Registers [decoration], returning `null` for a disposed marker.
  TerminalDecoration? registerDecoration(TerminalDecoration decoration) {
    if (decoration.marker.isDisposed) return null;
    late final Disposable markerListener;
    late final Disposable decorationListener;
    markerListener = decoration.marker.onDispose.listen(
      (_) => decoration.dispose(),
    );
    decorationListener = decoration.onDispose.listen((_) {
      decorationListener.dispose();
      if (_decorations.delete(decoration)) {
        _lineCache.removeDecoration(decoration);
        _onDecorationRemoved.fire(decoration);
      }
      markerListener.dispose();
    });
    _decorations.insert(decoration);
    _lineCache.addDecoration(decoration);
    _onDecorationRegistered.fire(decoration);
    return decoration;
  }

  /// Disposes and removes all decorations.
  void reset() {
    for (final decoration in _decorations.values()) {
      decoration.dispose();
    }
    _decorations.clear();
    _lineCache.clear();
  }

  /// Returns decorations covering [x] on absolute buffer [line].
  Iterable<TerminalDecoration> getDecorationsAtCell(
    int x,
    int line, {
    TerminalDecorationLayer? layer,
  }) sync* {
    final bucket = _lineCache.getDecorationsOnLine(line);
    if (bucket == null) return;
    for (final decoration in bucket) {
      if (x >= decoration.x &&
          x < decoration.x + decoration.width &&
          (layer == null || decoration.layer == layer)) {
        yield decoration;
      }
    }
  }

  /// Calls [callback] for each decoration covering the requested cell.
  void forEachDecorationAtCell(
    int x,
    int line,
    TerminalDecorationLayer? layer,
    void Function(TerminalDecoration decoration) callback,
  ) {
    getDecorationsAtCell(x, line, layer: layer).forEach(callback);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    reset();
    _onDecorationRegistered.dispose();
    _onDecorationRemoved.dispose();
    super.dispose();
  }
}
