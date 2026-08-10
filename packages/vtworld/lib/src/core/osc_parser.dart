import 'dart:async';
import 'dart:typed_data';

import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/parser_constants.dart';
import 'package:vtworld/src/core/string_builder.dart';

/// Stateful handler for one OSC identifier.
abstract interface class OscSubHandler {
  /// Begins a payload.
  void start();

  /// Receives UTF-32 payload code points in `[start, end)`.
  void put(Uint32List data, int start, int end);

  /// Ends or aborts the payload.
  // Positional to preserve xterm's `end(success)` handler contract.
  // ignore: avoid_positional_boolean_parameters
  FutureOr<bool> end(bool success);
}

/// Fallback notification for an unregistered OSC identifier.
typedef OscFallbackHandler =
    void Function(int identifier, String action, [Object? payload]);

enum _OscState { start, identifier, payload, abort }

/// Parser for OSC numeric identifiers and payload dispatch.
final class OscParser implements Disposable {
  _OscState _state = _OscState.start;
  List<OscSubHandler> _active = <OscSubHandler>[];
  int _identifier = -1;
  final Map<int, List<OscSubHandler>> _handlers = <int, List<OscSubHandler>>{};
  OscFallbackHandler _fallback = _noopFallback;
  bool _paused = false;
  int _loopPosition = 0;
  bool _fallThrough = false;
  bool _isDisposed = false;

  /// Registers [handler] last, giving it highest priority.
  Disposable registerHandler(int identifier, OscSubHandler handler) {
    final handlers = _handlers.putIfAbsent(identifier, () => <OscSubHandler>[])
      ..add(handler);
    return toDisposable(() => handlers.remove(handler));
  }

  /// Removes every handler for [identifier].
  void clearHandler(int identifier) => _handlers.remove(identifier);

  /// Replaces the fallback handler.
  // Method form preserves xterm's parser API.
  // ignore: use_setters_to_change_properties
  void setHandlerFallback(OscFallbackHandler handler) => _fallback = handler;

  /// Aborts any active payload and restores the initial state.
  void reset() {
    if (_state == _OscState.payload) {
      final start = _paused ? _loopPosition - 1 : _active.length - 1;
      for (var index = start; index >= 0; index--) {
        final _ = _active[index].end(false);
      }
    }
    _paused = false;
    _active = <OscSubHandler>[];
    _identifier = -1;
    _state = _OscState.start;
  }

  /// Starts parsing a new OSC command.
  void start() {
    reset();
    _state = _OscState.identifier;
  }

  /// Parses an identifier prefix and delivers remaining payload code points.
  void put(Uint32List data, int start, int end) {
    if (_state == _OscState.abort) return;
    var offset = start;
    if (_state == _OscState.identifier) {
      while (offset < end) {
        final code = data[offset++];
        if (code == 0x3b) {
          _state = _OscState.payload;
          _startPayload();
          break;
        }
        if (code < 0x30 || code > 0x39) {
          _state = _OscState.abort;
          return;
        }
        if (_identifier == -1) _identifier = 0;
        _identifier = _identifier * 10 + code - 0x30;
      }
    }
    if (_state == _OscState.payload && end - offset > 0) {
      _putPayload(data, offset, end);
    }
  }

  /// Ends a command, pausing when a handler returns a future.
  // Positional to preserve xterm's `end(success, promiseResult)` API.
  // ignore: avoid_positional_boolean_parameters
  Future<bool>? end(bool success, {bool promiseResult = true}) {
    if (_state == _OscState.start) return null;
    if (_state != _OscState.abort) {
      if (_state == _OscState.identifier) _startPayload();
      if (_active.isEmpty) {
        _fallback(_identifier, 'END', success);
      } else {
        final pending = _endHandlers(success, promiseResult);
        if (pending != null) return pending;
      }
    }
    _finish();
    return null;
  }

  void _startPayload() {
    _active = _handlers[_identifier] ?? <OscSubHandler>[];
    if (_active.isEmpty) {
      _fallback(_identifier, 'START');
    } else {
      for (var index = _active.length - 1; index >= 0; index--) {
        _active[index].start();
      }
    }
  }

  void _putPayload(Uint32List data, int start, int end) {
    if (_active.isEmpty) {
      _fallback(_identifier, 'PUT', String.fromCharCodes(data, start, end));
    } else {
      for (var index = _active.length - 1; index >= 0; index--) {
        _active[index].put(data, start, end);
      }
    }
  }

  Future<bool>? _endHandlers(bool success, bool promiseResult) {
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
    return null;
  }

  void _pause(int index, {required bool fallThrough}) {
    _paused = true;
    _loopPosition = index;
    _fallThrough = fallThrough;
  }

  void _finish() {
    _active = <OscSubHandler>[];
    _identifier = -1;
    _state = _OscState.start;
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _handlers.clear();
    _fallback = _noopFallback;
    _active = <OscSubHandler>[];
    _isDisposed = true;
  }

  static void _noopFallback(int _, String _, [Object? _]) {}
}

/// Adapts a complete string callback to [OscSubHandler].
final class OscHandler implements OscSubHandler {
  /// Creates a string handler.
  OscHandler(this._handler);

  /// Maximum accepted payload. Mutable to mirror xterm's private test seam.
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
