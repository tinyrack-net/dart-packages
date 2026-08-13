// Dart port of `packages/cli/src/services/terminal/spinner.ts`.

import 'dart:async' show Timer;

import 'package:cliweave/src/env.dart';
import 'package:cliweave/src/terminal/theme.dart';
import 'package:cliweave/src/write_stream.dart';

/// Mirror of the TS `Spinner` interface.
abstract class Spinner {
  /// Stops the spinner and reports [text] as a success.
  void succeed(String text);

  /// Stops the spinner and reports [text] as a failure.
  void fail(String text);

  /// Stops the spinner and reports [text] as a warning.
  void warn(String text);

  /// Stops the spinner without reporting a result.
  void stop();
}

/// Cancellable handle mirroring the TS `setInterval` id, injectable so tests
/// can drive ticks manually (the vitest fake-timer seam).
abstract class SpinnerTimer {
  /// Cancels future timer ticks.
  void cancel();
}

/// Callback used by [SpinnerTimerFactory].
typedef SpinnerTimerFactory = SpinnerTimer Function(
  Duration interval,
  void Function() onTick,
);

class _PeriodicSpinnerTimer implements SpinnerTimer {
  _PeriodicSpinnerTimer(Duration interval, void Function() onTick)
    : _timer = Timer.periodic(interval, (_) => onTick());

  final Timer _timer;

  @override
  void cancel() {
    _timer.cancel();
  }
}

SpinnerTimer _startPeriodicTimer(Duration interval, void Function() onTick) {
  return _PeriodicSpinnerTimer(interval, onTick);
}

/// Mirrors the TS module-level `isCI` expression:
/// `Boolean(envValue("CI") ?? envValue("NO_COLOR") ??
///  envValue("FORCE_COLOR") === "0")`.
bool _resolveIsCI(EnvLookup readEnv) {
  final marker = readEnv('CI') ?? readEnv('NO_COLOR');
  if (marker != null) {
    return marker.isNotEmpty;
  }
  return readEnv('FORCE_COLOR') == '0';
}

ColorTheme _defaultColorTheme() => color;

class _SpinnerHandle implements Spinner {
  _SpinnerHandle(this._onSucceed, this._onFail, this._onWarn, this._onStop);

  final void Function(String msg) _onSucceed;
  final void Function(String msg) _onFail;
  final void Function(String msg) _onWarn;
  final void Function() _onStop;

  @override
  void succeed(String text) => _onSucceed(text);

  @override
  void fail(String text) => _onFail(text);

  @override
  void warn(String text) => _onWarn(text);

  @override
  void stop() => _onStop();
}

/// The optional [color]/[symbols]/[readEnv]/[startInterval] overrides are the DI
/// seams replacing the vitest theme mock, `vi.stubEnv`, and fake timers.
Spinner createSpinner(
  WriteStream stream,
  String text, {
  ColorTheme? color,
  Symbols? symbols,
  EnvLookup? readEnv,
  SpinnerTimerFactory? startInterval,
}) {
  final theme = color ?? _defaultColorTheme();
  final syms = symbols ?? SYMBOLS;
  final isCI = _resolveIsCI(readEnv ?? lookupPlatformEnv);
  final frames = syms.spinner;
  var frameIndex = 0;
  SpinnerTimer? intervalId;
  var running = true;

  void clear() {
    // The TS guard also checks that clearLine/cursorTo exist; the Dart
    // WriteStream interface always provides them.
    if (stream.isTTY) {
      stream.clearLine(0);
      stream.cursorTo(0);
    }
  }

  void writeLine(String msg) {
    clear();
    stream.write('$msg\n');
  }

  void render() {
    if (!running) {
      return;
    }
    final frame = '${theme.info(frames[frameIndex])} ${theme.dim(text)}';
    if (stream.isTTY) {
      // Overwrite the previous frame in place instead of erasing the whole
      // line first: move to column 0, redraw over the old glyph/text, then
      // clear only any trailing leftover from a longer previous frame. A full
      // `\x1B[2K` erase before the redraw leaves a momentary blank line that
      // reads as flicker on Windows terminals; overwriting avoids it.
      stream.cursorTo(0);
      stream.write(frame);
      stream.clearLine(1);
    } else {
      stream.write(frame);
    }
    frameIndex = (frameIndex + 1) % frames.length;
  }

  if (stream.isTTY && !isCI) {
    intervalId = (startInterval ?? _startPeriodicTimer)(
      const Duration(milliseconds: 80),
      render,
    );
    render();
  } else {
    stream.write('${theme.dim(syms.bullet)} ${theme.dim(text)}\n');
  }

  return _SpinnerHandle(
    (String msg) {
      running = false;
      intervalId?.cancel();
      writeLine('${theme.success(syms.success)} ${theme.success(msg)}');
    },
    (String msg) {
      running = false;
      intervalId?.cancel();
      writeLine('${theme.error(syms.error)} ${theme.error(msg)}');
    },
    (String msg) {
      running = false;
      intervalId?.cancel();
      writeLine('${theme.warn(syms.warn)} ${theme.warn(msg)}');
    },
    () {
      running = false;
      intervalId?.cancel();
      clear();
    },
  );
}
