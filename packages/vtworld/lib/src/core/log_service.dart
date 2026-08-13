import 'dart:async';

import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/options.dart';

/// Platform-neutral fallback used when no [TerminalLogger] is configured.
typedef TerminalLogSink = void Function(
  TerminalLogLevel level,
  String message,
  List<Object?> optionalParameters,
);

/// Applies xterm log levels, lazy parameters, prefixes, and live options.
final class TerminalLogService extends DisposableStore {
  /// Creates a logging service over mutable [options].
  TerminalLogService(TerminalOptions options, {TerminalLogSink? sink})
    : this._(options, sink ?? _defaultSink);

  TerminalLogService._(this._options, this._sink)
    : _logLevel = _options.logLevel {
    add(
      _options.onSpecificOptionChange('logLevel', (_) {
        _logLevel = _options.logLevel;
      }),
    );
  }

  static const String _prefix = 'xterm.js: ';
  final TerminalOptions _options;
  final TerminalLogSink _sink;
  TerminalLogLevel _logLevel;

  /// Current minimum enabled severity.
  TerminalLogLevel get logLevel => _logLevel;

  /// Emits a trace message when enabled.
  void trace(String message, [List<Object?> parameters = const <Object?>[]]) {
    _emit(TerminalLogLevel.trace, message, parameters);
  }

  /// Emits a debug message when enabled.
  void debug(String message, [List<Object?> parameters = const <Object?>[]]) {
    _emit(TerminalLogLevel.debug, message, parameters);
  }

  /// Emits an informational message when enabled.
  void info(String message, [List<Object?> parameters = const <Object?>[]]) {
    _emit(TerminalLogLevel.info, message, parameters);
  }

  /// Emits a warning message when enabled.
  void warning(String message, [List<Object?> parameters = const <Object?>[]]) {
    _emit(TerminalLogLevel.warning, message, parameters);
  }

  /// Emits an error message when enabled.
  void error(String message, [List<Object?> parameters = const <Object?>[]]) {
    _emit(TerminalLogLevel.error, message, parameters);
  }

  void _emit(TerminalLogLevel level, String message, List<Object?> parameters) {
    if (_logLevel.index > level.index || _logLevel == TerminalLogLevel.off) {
      return;
    }
    final evaluated = <Object?>[
      for (final parameter in parameters)
        parameter is Object? Function() ? parameter() : parameter,
    ];
    final logger = _options.logger;
    if (logger != null) {
      switch (level) {
        case TerminalLogLevel.trace:
          logger.trace(message, evaluated);
        case TerminalLogLevel.debug:
          logger.debug(message, evaluated);
        case TerminalLogLevel.info:
          logger.info(message, evaluated);
        case TerminalLogLevel.warning:
          logger.warn(message, evaluated);
        case TerminalLogLevel.error:
          logger.error(message, evaluated);
        case TerminalLogLevel.off:
          return;
      }
      return;
    }
    _sink(level, '$_prefix$message', evaluated);
  }

  static void _defaultSink(
    TerminalLogLevel level,
    String message,
    List<Object?> parameters,
  ) {
    Zone.current.print(
      parameters.isEmpty ? message : '$message ${parameters.join(' ')}',
    );
  }
}
