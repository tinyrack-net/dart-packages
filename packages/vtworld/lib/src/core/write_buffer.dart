import 'dart:async';
import 'dart:typed_data';

import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';

/// A parser action used by [WriteBuffer].
///
/// Returning a future pauses the active chunk. The action is called again for
/// that same chunk with the resolved boolean so a resumable parser can continue
/// from its saved state, matching xterm.js' write-buffer contract.
typedef WriteBufferAction =
    Object? Function(
      Object data, [
      // The positional boolean is fixed by xterm's continuation contract.
      // ignore: avoid_positional_boolean_parameters
      bool? promiseResult,
    ]);

/// xterm.js' ordered, time-sliced terminal input queue.
final class WriteBuffer extends DisposableStore {
  /// Creates a write buffer around a resumable parser action.
  WriteBuffer(this._action);

  static const int _discardWatermark = 50000000;
  static const int _writeTimeoutMilliseconds = 12;
  static const int _writeBufferLengthThreshold = 50;

  final WriteBufferAction _action;
  final List<Object> _writeBuffer = <Object>[];
  final List<void Function()?> _callbacks = <void Function()?>[];
  final TerminalEventEmitter<TerminalVoid> _onWriteParsed =
      TerminalEventEmitter<TerminalVoid>();
  final Stopwatch _clock = Stopwatch()..start();

  Timer? _innerWriteTimer;
  int _pendingData = 0;
  int _bufferOffset = 0;
  bool _isSyncWriting = false;

  /// Whether an [_innerWrite] chunk is still awaiting its parser handler.
  bool _isAsyncWriting = false;
  int _syncCalls = 0;
  bool _didUserInput = false;

  /// Fires after one synchronous or time-sliced parsing batch completes.
  TerminalEvent<TerminalVoid> get onWriteParsed => _onWriteParsed.event;

  /// Marks that the next first chunk should begin parsing immediately.
  void handleUserInput() {
    _didUserInput = true;
  }

  /// Processes all queued chunks without yielding to the event loop.
  ///
  /// Like xterm.js, this cannot wait for asynchronous parser handlers.
  ///
  /// It also cannot run *during* one. xterm.js' parser is synchronous and
  /// resumable, so a flush that lands mid-handler simply parses; this port's
  /// parser is genuinely asynchronous and refuses to be re-entered, so the
  /// flush would throw and abandon the chunk it was holding. A caller such as
  /// a terminal resize fires on any frame, including one where a handler is
  /// still awaiting, so the queue is left to the pending inner write instead.
  /// The chunks stay queued and reach the parser in order once it resumes.
  void flushSync() {
    if (isDisposed || _isSyncWriting || _isAsyncWriting) return;
    _isSyncWriting = true;
    var didProcess = false;
    while (_writeBuffer.isNotEmpty) {
      final chunk = _writeBuffer.removeAt(0);
      // The upstream assignment-in-condition stops on an empty JS string.
      if (chunk is String && chunk.isEmpty) break;
      didProcess = true;
      _action(chunk);
      if (_callbacks.isNotEmpty) _callbacks.removeAt(0)?.call();
    }
    _pendingData = 0;
    _bufferOffset = 0x7fffffff;
    _writeBuffer.clear();
    _callbacks.clear();
    _isSyncWriting = false;
    if (didProcess) _onWriteParsed.fire(TerminalVoid.value);
  }

  /// Performs an immediate, recursion-safe write.
  ///
  /// This API is deprecated upstream because async handlers make it
  /// unreliable, but remains implemented for exact compatibility.
  void writeSync(Object data, [int? maxSubsequentCalls]) {
    _checkData(data);
    if (isDisposed) return;
    if (maxSubsequentCalls != null && _syncCalls > maxSubsequentCalls) {
      _syncCalls = 0;
      return;
    }
    _pendingData += _dataLength(data);
    _writeBuffer.add(data);
    _callbacks.add(null);
    _syncCalls++;
    // Queued above, so a parser still awaiting a handler parses this in order
    // when it resumes rather than being re-entered here. See [flushSync].
    if (_isSyncWriting || _isAsyncWriting) return;
    _isSyncWriting = true;
    while (_writeBuffer.isNotEmpty) {
      final chunk = _writeBuffer.removeAt(0);
      if (chunk is String && chunk.isEmpty) break;
      _action(chunk);
      if (_callbacks.isNotEmpty) _callbacks.removeAt(0)?.call();
    }
    _pendingData = 0;
    _bufferOffset = 0x7fffffff;
    _isSyncWriting = false;
    _syncCalls = 0;
  }

  /// Adds [data] to the ordered parser queue.
  void write(Object data, [void Function()? callback]) {
    _checkData(data);
    if (isDisposed) return;
    if (_pendingData > _discardWatermark) {
      throw StateError(
        'write data discarded, use flow control to avoid losing data',
      );
    }
    if (_writeBuffer.isEmpty) {
      _bufferOffset = 0;
      if (_didUserInput) {
        _didUserInput = false;
        _pendingData += _dataLength(data);
        _writeBuffer.add(data);
        _callbacks.add(callback);
        _innerWrite();
        return;
      }
      _scheduleInnerWrite();
    }
    _pendingData += _dataLength(data);
    _writeBuffer.add(data);
    _callbacks.add(callback);
  }

  void _scheduleInnerWrite({int lastTime = 0, bool promiseResult = true}) {
    if (isDisposed) return;
    _innerWriteTimer?.cancel();
    _innerWriteTimer = Timer(
      Duration.zero,
      () => _innerWrite(lastTime: lastTime, promiseResult: promiseResult),
    );
  }

  void _innerWrite({int lastTime = 0, bool promiseResult = true}) {
    if (isDisposed) return;
    final startTime = lastTime == 0 ? _clock.elapsedMilliseconds : lastTime;
    while (_writeBuffer.length > _bufferOffset) {
      final data = _writeBuffer[_bufferOffset];
      final result = _action(data, promiseResult);
      if (result is Future<bool>) {
        // The parser now owns this chunk until the handler resolves, and it
        // cannot be re-entered meanwhile. See [flushSync].
        _isAsyncWriting = true;
        unawaited(
          result.then(
            (resolved) {
              _isAsyncWriting = false;
              if (isDisposed) return;
              if (_clock.elapsedMilliseconds - startTime >=
                  _writeTimeoutMilliseconds) {
                _scheduleInnerWrite(promiseResult: resolved);
              } else {
                _innerWrite(lastTime: startTime, promiseResult: resolved);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              _isAsyncWriting = false;
              scheduleMicrotask(
                () => Error.throwWithStackTrace(error, stackTrace),
              );
              if (!isDisposed) {
                _innerWrite(lastTime: startTime, promiseResult: false);
              }
            },
          ),
        );
        return;
      }
      if (result is Future) {
        throw StateError('WriteBuffer action futures must resolve to bool');
      }
      _callbacks[_bufferOffset]?.call();
      _bufferOffset++;
      _pendingData -= _dataLength(data);
      if (_clock.elapsedMilliseconds - startTime >= _writeTimeoutMilliseconds) {
        break;
      }
    }
    if (_writeBuffer.length > _bufferOffset) {
      if (_bufferOffset > _writeBufferLengthThreshold) {
        _writeBuffer.removeRange(0, _bufferOffset);
        _callbacks.removeRange(0, _bufferOffset);
        _bufferOffset = 0;
      }
      _scheduleInnerWrite();
    } else {
      _writeBuffer.clear();
      _callbacks.clear();
      _pendingData = 0;
      _bufferOffset = 0;
    }
    _onWriteParsed.fire(TerminalVoid.value);
  }

  static int _dataLength(Object data) {
    if (data is String) return data.length;
    if (data is Uint8List) return data.length;
    throw ArgumentError.value(data, 'data', 'must be String or Uint8List');
  }

  static void _checkData(Object data) {
    _dataLength(data);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _innerWriteTimer?.cancel();
    _innerWriteTimer = null;
    _writeBuffer.clear();
    _callbacks.clear();
    _pendingData = 0;
    _bufferOffset = 0;
    _onWriteParsed.dispose();
    super.dispose();
  }
}
