import 'dart:async';

import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/options.dart';

/// Timer boundary used by the renderer's blinking-text state machine.
abstract interface class TextBlinkTimerHost {
  /// Starts a repeating callback and returns its opaque identifier.
  int setInterval(void Function() callback, Duration duration);

  /// Cancels the repeating callback identified by [id].
  void clearInterval(int id);
}

/// Dart timer implementation of [TextBlinkTimerHost].
final class DartTextBlinkTimerHost implements TextBlinkTimerHost, Disposable {
  final Map<int, Timer> _timers = <int, Timer>{};
  var _nextId = 1;
  bool _isDisposed = false;

  @override
  int setInterval(void Function() callback, Duration duration) {
    if (_isDisposed) throw StateError('Timer host has been disposed');
    final id = _nextId++;
    _timers[id] = Timer.periodic(duration, (_) => callback());
    return id;
  }

  @override
  void clearInterval(int id) => _timers.remove(id)?.cancel();

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

/// Controls the blink phase and timer lifetime for blinking terminal text.
final class TextBlinkStateManager extends DisposableStore {
  /// Creates a blink manager using live [options].
  TextBlinkStateManager({
    required void Function() renderCallback,
    required TextBlinkTimerHost timerHost,
    required TerminalOptions options,
  }) : this._(renderCallback, timerHost, options);

  TextBlinkStateManager._(
    this._renderCallback,
    this._timerHost,
    TerminalOptions options,
  ) {
    add(
      options.onSpecificOptionChange('blinkIntervalDuration', (value) {
        setIntervalDuration(value! as int);
      }),
    );
    setIntervalDuration(options.blinkIntervalDuration);
  }

  final void Function() _renderCallback;
  final TextBlinkTimerHost _timerHost;
  var _intervalDuration = 0;
  int? _interval;
  var _blinkOn = true;
  var _needsBlinkInViewport = false;
  var _isViewportVisible = true;

  /// Whether blinking text is currently visible.
  bool get isBlinkOn => _blinkOn;

  /// Whether a non-zero blink interval is configured.
  bool get isEnabled => _intervalDuration > 0;

  /// Updates whether the visible viewport contains blinking cells.
  void setNeedsBlinkInViewport({required bool value}) {
    if (_needsBlinkInViewport == value) return;
    _needsBlinkInViewport = value;
    _updateIntervalState();
  }

  /// Pauses blinking while the viewport is hidden.
  void setViewportVisible({required bool value}) {
    if (_isViewportVisible == value) return;
    _isViewportVisible = value;
    _updateIntervalState();
  }

  /// Updates the blink interval in milliseconds.
  void setIntervalDuration(int duration) {
    if (duration == _intervalDuration) return;
    _intervalDuration = duration;
    _clearInterval();
    _updateIntervalState();
  }

  void _updateIntervalState() {
    final shouldBlink =
        _intervalDuration > 0 && _needsBlinkInViewport && _isViewportVisible;
    if (shouldBlink) {
      if (_interval != null) return;
      final wasBlinkOn = _blinkOn;
      _blinkOn = true;
      _interval = _timerHost.setInterval(() {
        _blinkOn = !_blinkOn;
        _renderCallback();
      }, Duration(milliseconds: _intervalDuration));
      if (!wasBlinkOn) _renderCallback();
      return;
    }
    _clearInterval();
    if (!_blinkOn) {
      _blinkOn = true;
      _renderCallback();
    }
  }

  void _clearInterval() {
    final interval = _interval;
    if (interval == null) return;
    _timerHost.clearInterval(interval);
    _interval = null;
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _clearInterval();
    super.dispose();
  }
}
