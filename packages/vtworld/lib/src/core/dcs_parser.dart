import 'dart:async';
import 'dart:typed_data';

import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/params.dart';
import 'package:vtworld/src/core/parser_constants.dart';
import 'package:vtworld/src/core/string_builder.dart';

/// Stateful handler for one DCS identifier.
abstract interface class DcsSubHandler {
  /// Begins a payload with borrowed parser [params].
  void hook(Params params);

  /// Receives UTF-32 payload code points in `[start, end)`.
  void put(Uint32List data, int start, int end);

  /// Ends or aborts the payload.
  // Positional to preserve xterm's `unhook(success)` handler contract.
  // ignore: avoid_positional_boolean_parameters
  FutureOr<bool> unhook(bool success);
}

/// Fallback notification for an unregistered DCS identifier.
typedef DcsFallbackHandler =
    void Function(int identifier, String action, [Object? payload]);

/// Parser for DCS identifier, parameters and payload dispatch.
final class DcsParser implements Disposable {
  final Map<int, List<DcsSubHandler>> _handlers = <int, List<DcsSubHandler>>{};
  List<DcsSubHandler> _active = <DcsSubHandler>[];
  int _identifier = 0;
  DcsFallbackHandler _fallback = _noopFallback;
  bool _paused = false;
  int _loopPosition = 0;
  bool _fallThrough = false;
  bool _isDisposed = false;

  /// Registers [handler] last, giving it highest priority.
  Disposable registerHandler(int identifier, DcsSubHandler handler) {
    final handlers = _handlers.putIfAbsent(identifier, () => <DcsSubHandler>[])
      ..add(handler);
    return toDisposable(() => handlers.remove(handler));
  }

  /// Removes every handler for [identifier].
  void clearHandler(int identifier) => _handlers.remove(identifier);

  /// Replaces the fallback handler.
  // Method form preserves xterm's parser API.
  // ignore: use_setters_to_change_properties
  void setHandlerFallback(DcsFallbackHandler handler) => _fallback = handler;

  /// Aborts active handlers and resets parser state.
  void reset() {
    if (_active.isNotEmpty) {
      final start = _paused ? _loopPosition - 1 : _active.length - 1;
      for (var index = start; index >= 0; index--) {
        final _ = _active[index].unhook(false);
      }
    }
    _paused = false;
    _active = <DcsSubHandler>[];
    _identifier = 0;
  }

  /// Starts [identifier] with [params], newest handler first.
  void hook(int identifier, Params params) {
    reset();
    _identifier = identifier;
    _active = _handlers[identifier] ?? <DcsSubHandler>[];
    if (_active.isEmpty) {
      _fallback(identifier, 'HOOK', params);
    } else {
      for (var index = _active.length - 1; index >= 0; index--) {
        _active[index].hook(params);
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

  /// Ends a payload, pausing when a handler returns a future.
  // Positional to preserve xterm's `unhook(success, promiseResult)` API.
  // ignore: avoid_positional_boolean_parameters
  Future<bool>? unhook(bool success, {bool promiseResult = true}) {
    if (_active.isEmpty) {
      _fallback(_identifier, 'UNHOOK', success);
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
        result = _active[index].unhook(success);
        if (result == true) break;
        if (result is Future<bool>) {
          _pause(index, fallThrough: false);
          return result;
        }
      }
      index--;
    }
    for (; index >= 0; index--) {
      result = _active[index].unhook(false);
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
    _active = <DcsSubHandler>[];
    _identifier = 0;
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _handlers.clear();
    _fallback = _noopFallback;
    _active = <DcsSubHandler>[];
    _isDisposed = true;
  }

  static void _noopFallback(int _, String _, [Object? _]) {}
}

final Params _emptyParams = Params()..addParam(0);

/// Adapts a complete string callback to [DcsSubHandler].
final class DcsHandler implements DcsSubHandler {
  /// Creates a string-and-parameters handler.
  DcsHandler(this._handler);

  /// Maximum accepted payload. Mutable to mirror xterm's private test seam.
  static int payloadLimit = defaultPayloadLimit;

  /// xterm's `ParserConstants.PAYLOAD_LIMIT` value.
  static const int defaultPayloadLimit = parserPayloadLimit;

  final FutureOr<bool> Function(String data, Params params) _handler;
  final LimitedStringBuilder _data = LimitedStringBuilder(payloadLimit);
  Params _params = _emptyParams;
  bool _hitLimit = false;

  @override
  void hook(Params params) {
    _params = params.length > 1 || params.params[0] != 0
        ? params.clone()
        : _emptyParams;
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
  FutureOr<bool> unhook(bool success) {
    FutureOr<bool> result = false;
    if (!_hitLimit && success) {
      result = _handler(_data.toString(), _params);
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
    _params = _emptyParams;
    _data.reset();
    _hitLimit = false;
  }
}
