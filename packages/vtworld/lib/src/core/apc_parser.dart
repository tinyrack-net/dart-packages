import 'dart:async';
import 'dart:typed_data';

import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/parser_constants.dart';
import 'package:vtworld/src/core/string_builder.dart';

/// Stateful handler for one APC identifier.
abstract interface class ApcSubHandler {
  /// Begins a payload.
  void start();

  /// Receives UTF-32 payload code points in `[start, end)`.
  void put(Uint32List data, int start, int end);

  /// Ends or aborts the payload.
  // Positional to preserve xterm's `end(success)` handler contract.
  // ignore: avoid_positional_boolean_parameters
  FutureOr<bool> end(bool success);
}

/// Fallback notification for an unregistered APC identifier.
typedef ApcFallbackHandler = void Function(
  int identifier,
  String action, [
  Object? payload,
]);

/// Parser for APC identifier and payload dispatch.
final class ApcParser implements Disposable {
  final Map<int, List<ApcSubHandler>> _handlers = <int, List<ApcSubHandler>>{};
  List<ApcSubHandler> _active = <ApcSubHandler>[];
  int _identifier = 0;
  ApcFallbackHandler _fallback = _noopFallback;
  bool _paused = false;
  int _loopPosition = 0;
  bool _fallThrough = false;
  bool _isDisposed = false;

  /// Registers [handler] last, giving it highest priority.
  Disposable registerHandler(int identifier, ApcSubHandler handler) {
    final handlers = _handlers.putIfAbsent(identifier, () => <ApcSubHandler>[])
      ..add(handler);
    return toDisposable(() => handlers.remove(handler));
  }

  /// Removes every handler for [identifier].
  void clearHandler(int identifier) => _handlers.remove(identifier);

  /// Replaces the fallback handler.
  // Method form preserves xterm's parser API.
  // ignore: use_setters_to_change_properties
  void setHandlerFallback(ApcFallbackHandler handler) => _fallback = handler;

  /// Aborts active handlers and resets parser state.
  void reset() {
    if (_active.isNotEmpty) {
      final start = _paused ? _loopPosition - 1 : _active.length - 1;
      for (var index = start; index >= 0; index--) {
        final _ = _active[index].end(false);
      }
    }
    _paused = false;
    _active = <ApcSubHandler>[];
    _identifier = 0;
  }

  /// Starts [identifier], notifying handlers from newest to oldest.
  void start(int identifier) {
    reset();
    _identifier = identifier;
    _active = _handlers[identifier] ?? <ApcSubHandler>[];
    if (_active.isEmpty) {
      _fallback(identifier, 'START');
    } else {
      for (var index = _active.length - 1; index >= 0; index--) {
        _active[index].start();
      }
    }
  }

  /// Delivers a UTF-32 payload slice.
  void put(Uint32List data, int start, int end) {
    if (_active.isEmpty) {
      _fallback(_identifier, 'PUT', String.fromCharCodes(data, start, end));
    } else {
      for (var index = _active.length - 1; index >= 0; index--) {
        _active[index].put(data, start, end);
      }
    }
  }

  /// Ends a payload. When an async handler is encountered, the returned
  /// future's boolean must be passed back as [promiseResult] on the next call.
  // Positional to preserve xterm's `end(success, promiseResult)` API.
  // ignore: avoid_positional_boolean_parameters
  Future<bool>? end(bool success, {bool promiseResult = true}) {
    if (_active.isEmpty) {
      _fallback(_identifier, 'END', success);
      _finish();
      return null;
    }
    FutureOr<bool> result = false;
    var index = _active.length - 1;
    var fallThrough = false;
    if (_paused) {
      index = _loopPosition - 1;
      result = promiseResult;
      fallThrough = _fallThrough;
      _paused = false;
    }
    if (!fallThrough && result == false) {
      for (; index >= 0; index--) {
        result = _active[index].end(success);
        if (result == true) break;
        if (result is Future<bool>) {
          _pause(index, fallThrough: false);
          return result;
        }
      }
      index--;
    }
    for (; index >= 0; index--) {
      result = _active[index].end(false);
      if (result is Future<bool>) {
        _pause(index, fallThrough: true);
        return result;
      }
    }
    _finish();
    return null;
  }

  void _pause(int index, {required bool fallThrough}) {
    _paused = true;
    _loopPosition = index;
    _fallThrough = fallThrough;
  }

  void _finish() {
    _active = <ApcSubHandler>[];
    _identifier = 0;
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _handlers.clear();
    _fallback = _noopFallback;
    _active = <ApcSubHandler>[];
    _isDisposed = true;
  }

  static void _noopFallback(int _, String _, [Object? _]) {}
}

/// Adapts a complete string callback to [ApcSubHandler].
final class ApcHandler implements ApcSubHandler {
  /// Creates a string handler.
  ApcHandler(this._handler);

  /// Maximum accepted payload. Mutable to mirror xterm's private test seam;
  /// production code leaves this at [defaultPayloadLimit].
  static int payloadLimit = defaultPayloadLimit;

  /// xterm's `ParserConstants.PAYLOAD_LIMIT` value.
  static const int defaultPayloadLimit = parserPayloadLimit;

  final FutureOr<bool> Function(String data) _handler;
  final LimitedStringBuilder _data = LimitedStringBuilder(payloadLimit);
  bool _hitLimit = false;

  @override
  void start() {
    _data.reset();
    _hitLimit = false;
  }

  @override
  void put(Uint32List data, int start, int end) {
    if (_hitLimit) return;
    if (_data.append(String.fromCharCodes(data, start, end))) {
      _hitLimit = true;
    }
  }

  @override
  FutureOr<bool> end(bool success) {
    FutureOr<bool> result = false;
    if (!_hitLimit && success) {
      result = _handler(_data.toString());
      if (result is Future<bool>) {
        return result.then((value) {
          _reset();
          return value;
        });
      }
    }
    _reset();
    return result;
  }

  void _reset() {
    _data.reset();
    _hitLimit = false;
  }
}
