import 'dart:async';
import 'dart:convert';

import 'model.dart';
import 'process.dart';

/// Creates independent Lua sessions over one native-host distribution.
final class LuaToolRuntime<T extends Object> {
  /// Creates a runtime.
  LuaToolRuntime({
    required this.host,
    required this.processLauncher,
    required this.clock,
    required this.ids,
  });

  /// Native host command.
  final LuaHostCommand host;

  /// Process composition port.
  final LuaHostProcessLauncher processLauncher;

  /// Runtime clock.
  final LuaClock clock;

  /// Cell ID source.
  final LuaIdGenerator ids;

  final Set<LuaRuntimeSession<T>> _sessions = {};

  /// Creates a session with isolated store, cells, and resources.
  LuaRuntimeSession<T> createSession({
    LuaRuntimeLimits limits = const LuaRuntimeLimits(),
  }) {
    final session = LuaRuntimeSession<T>._(this, limits);
    _sessions.add(session);
    return session;
  }

  /// Reclaims expired cells from every session.
  void sweep() {
    for (final session in _sessions) {
      session.sweep();
    }
  }

  /// Terminates every session and helper process.
  Future<void> close() async {
    await Future.wait(
      List<LuaRuntimeSession<T>>.of(
        _sessions,
      ).map((session) => session.close()),
    );
    _sessions.clear();
  }

  void _forget(LuaRuntimeSession<T> session) => _sessions.remove(session);
}

/// Session-isolated cell collection and JSON store.
final class LuaRuntimeSession<T extends Object> {
  LuaRuntimeSession._(this._runtime, this.limits);

  final LuaToolRuntime<T> _runtime;

  /// Limits applied to cells in this session.
  final LuaRuntimeLimits limits;

  final Map<String, _LuaCell<T>> _cells = {};
  Map<String, Object?> _store = {};
  bool _closed = false;

  /// Snapshot of the JSON-serializable session store.
  Map<String, Object?> get store => Map.unmodifiable(_store);

  /// Starts a fresh VM.
  Future<LuaCellDelta<T>> execute(
    LuaExecuteRequest request,
    LuaExecutionContext<T> context, {
    String workingDirectory = '.',
  }) async {
    if (_closed) throw StateError('Lua runtime session is closed.');
    final sourceBytes = utf8.encode(request.source).length;
    if (sourceBytes > limits.maxSourceBytes) {
      return LuaCellDelta<T>(
        cellId: '',
        output: '',
        running: false,
        error: LuaLimitException(
          'Lua source exceeds ${limits.maxSourceBytes} bytes.',
        ),
      );
    }
    sweep();
    if (_cells.length >= limits.maxLiveCells) {
      final oldest = _cells.values.reduce(
        (left, right) => left.lastUsed.isBefore(right.lastUsed) ? left : right,
      );
      await _remove(oldest, terminate: true);
    }
    final id = 'lua-${_runtime.ids.generate()}';
    final process = await _runtime.processLauncher.start(
      _runtime.host.withEnvironment({
        'LUA_TOOL_RUNTIME_MEMORY_LIMIT_BYTES': '${limits.maxMemoryBytes}',
      }),
      workingDirectory: workingDirectory,
    );
    final cell = _LuaCell<T>(
      id: id,
      process: process,
      clock: _runtime.clock,
      limits: limits,
      context: context,
      onStore: (value) => _store = value,
      onTerminal: (value) => _cells.remove(value.id),
    );
    _cells[id] = cell;
    await cell.initialize(request.source, request.tools, _store);
    final delta = await cell.read(
      _boundedWait(request.yieldTime),
      request.maxOutputTokens,
    );
    if (!delta.running) await _remove(cell, terminate: false);
    return delta;
  }

  /// Observes, resumes, or terminates an existing cell.
  Future<LuaCellDelta<T>> wait(
    LuaWaitRequest request,
    LuaExecutionContext<T> context,
  ) async {
    if (_closed) throw StateError('Lua runtime session is closed.');
    sweep();
    final cell = _cells[request.cellId];
    if (cell == null) {
      return LuaCellDelta<T>(
        cellId: request.cellId,
        output: '',
        running: false,
        error: const LuaCellNotFoundException('Lua cell not found.'),
      );
    }
    cell.context = context;
    cell.bindCancellation();
    if (request.terminate) {
      await _remove(cell, terminate: true);
      return LuaCellDelta<T>(
        cellId: request.cellId,
        output: cell.drain(request.maxOutputTokens),
        running: false,
        terminated: true,
      );
    }
    await cell.continueIfYielded();
    final delta = await cell.read(
      _boundedWait(request.yieldTime),
      request.maxOutputTokens,
    );
    if (!delta.running) await _remove(cell, terminate: false);
    return delta;
  }

  Duration _boundedWait(Duration requested) {
    if (requested <= Duration.zero) return const Duration(milliseconds: 1);
    return requested > limits.maxYieldTime ? limits.maxYieldTime : requested;
  }

  /// Terminates expired cells.
  void sweep() {
    final now = _runtime.clock.nowUtc();
    for (final cell in List<_LuaCell<T>>.of(_cells.values)) {
      if (now.difference(cell.lastUsed) > limits.idleTimeout ||
          now.difference(cell.startedAt) > limits.executionWatchdog) {
        unawaited(_remove(cell, terminate: true));
      }
    }
  }

  /// Terminates all cells in this session.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(
      List<_LuaCell<T>>.of(
        _cells.values,
      ).map((cell) => _remove(cell, terminate: true)),
    );
    _runtime._forget(this);
  }

  Future<void> _remove(_LuaCell<T> cell, {required bool terminate}) async {
    _cells.remove(cell.id);
    await cell.close(terminate: terminate);
  }
}

final class _LuaCell<T extends Object> {
  _LuaCell({
    required this.id,
    required LuaHostProcess process,
    required LuaClock clock,
    required this.limits,
    required this.context,
    required this.onStore,
    required this.onTerminal,
  }) : _process = process,
       _clock = clock,
       startedAt = clock.nowUtc(),
       lastUsed = clock.nowUtc() {
    _subscription = process.outputs.listen(
      _receiveData,
      onError: (Object error, StackTrace stack) =>
          _fail(LuaHostException('$error')),
      onDone: _outputClosed,
    );
    unawaited(
      process.exitCode.then<void>(
        (code) {
          if (!_terminal && code != 0) {
            _fail(LuaHostException('Lua host exited with code $code.'));
          }
        },
        onError: (Object error) {
          _fail(LuaHostException('Lua host crashed: $error'));
        },
      ),
    );
    bindCancellation();
  }

  final String id;
  final LuaHostProcess _process;
  final LuaClock _clock;
  final LuaRuntimeLimits limits;
  final void Function(Map<String, Object?>) onStore;
  final void Function(_LuaCell<T>) onTerminal;
  final Map<String, LuaOpaqueResource<T>> _resources = {};
  final Set<String> _emittedHandles = {};
  final Set<String> _drainedHandles = {};
  final Set<String> _drainedEmittedHandles = {};
  final List<Object?> _notifications = [];
  late final StreamSubscription<String> _subscription;
  LuaExecutionContext<T> context;
  final DateTime startedAt;
  DateTime lastUsed;
  String _inputBuffer = '';
  String _output = '';
  LuaRuntimeException? _error;
  bool _terminal = false;
  bool _yielded = false;
  bool _closed = false;
  int _expectedSequence = 1;
  int _outboundSequence = 0;
  int _revision = 0;
  int _cancellationGeneration = 0;
  Completer<void> _changed = Completer<void>();

  void bindCancellation() {
    final generation = ++_cancellationGeneration;
    context.cancellation?.onCancel(() {
      if (generation == _cancellationGeneration) {
        unawaited(close(terminate: true));
      }
    });
  }

  Future<void> initialize(
    String source,
    List<LuaToolDefinition> tools,
    Map<String, Object?> store,
  ) => _send('init', {
    'source': source,
    'tools': [
      for (final tool in tools)
        {
          'name': tool.name,
          'description': tool.description,
          'kind': tool.kind,
          'namespace': ?tool.namespace,
          'exposure': tool.exposure,
          'input_schema': tool.inputSchema,
          'output_schema': ?tool.outputSchema,
        },
    ],
    'store': store,
    'memory_limit_bytes': limits.maxMemoryBytes,
  });

  Future<void> _send(String type, Map<String, Object?> payload) async {
    final encoded = jsonEncode({
      'version': luaHostProtocolVersion,
      'cell_id': id,
      'sequence_id': _outboundSequence++,
      'type': type,
      'payload': payload,
    });
    if (utf8.encode(encoded).length > limits.maxFrameBytes) {
      throw LuaLimitException(
        'Lua host frame exceeds ${limits.maxFrameBytes} bytes.',
      );
    }
    await _process.write('$encoded\n');
  }

  void _receiveData(String data) {
    if (_closed) return;
    _inputBuffer += data;
    while (true) {
      final newline = _inputBuffer.indexOf('\n');
      if (newline < 0) {
        if (utf8.encode(_inputBuffer).length > limits.maxFrameBytes) {
          _protocolFailure('Lua host frame exceeds limit.');
        }
        return;
      }
      final line = _inputBuffer.substring(0, newline);
      _inputBuffer = _inputBuffer.substring(newline + 1);
      if (line.isEmpty) continue;
      try {
        if (utf8.encode(line).length > limits.maxFrameBytes) {
          throw const FormatException('Lua host frame exceeds limit.');
        }
        final decoded = jsonDecode(line);
        if (decoded is! Map) throw const FormatException('Frame is not JSON.');
        _receiveFrame(Map<String, Object?>.from(decoded));
      } on Object catch (error) {
        _protocolFailure('$error');
        return;
      }
    }
  }

  void _receiveFrame(Map<String, Object?> frame) {
    if (frame['version'] != luaHostProtocolVersion ||
        frame['cell_id'] != id ||
        frame['sequence_id'] != _expectedSequence++) {
      throw const FormatException('Invalid frame identity or sequence.');
    }
    final rawPayload = frame['payload'];
    if (rawPayload is! Map) throw const FormatException('Invalid payload.');
    final payload = Map<String, Object?>.from(rawPayload);
    switch (frame['type']) {
      case 'output':
        _acceptOutput(payload);
      case 'tool_batch':
        unawaited(_dispatchBatch(payload));
      case 'yielded':
        _yielded = true;
        _acceptStore(payload['store']);
        _touch();
      case 'completed':
      case 'terminated':
        _acceptStore(payload['store']);
        _terminal = true;
        _touch();
      case 'error':
        _acceptStore(payload['store']);
        _fail(
          LuaScriptException(
            payload['message']?.toString() ?? 'Unknown Lua script error.',
          ),
        );
      default:
        throw FormatException('Unknown frame type: ${frame['type']}');
    }
  }

  void _acceptOutput(Map<String, Object?> payload) {
    final kind = payload['kind']?.toString();
    final value = payload['value'];
    if (kind == 'text') {
      _append(value is String ? value : jsonEncode(value));
    } else if (kind == 'notify') {
      _notifications.add(value);
    } else if (kind == 'image' ||
        kind == 'audio' ||
        kind == 'generated_image') {
      final handle = value is String ? value : null;
      if (handle == null || !_resources.containsKey(handle)) {
        throw const FormatException('Invalid or foreign resource handle.');
      }
      _emittedHandles.add(handle);
    } else {
      throw FormatException('Unsupported output kind: $kind');
    }
    _touch();
  }

  Future<void> _dispatchBatch(Map<String, Object?> payload) async {
    final rawCalls = payload['calls'];
    if (rawCalls is! List) {
      _protocolFailure('Invalid tool batch.');
      return;
    }
    try {
      final results = await Future.wait([
        for (final raw in rawCalls)
          _dispatchOne(Map<String, Object?>.from(raw! as Map)),
      ]);
      if (!_closed) await _send('tool_results', {'results': results});
    } on Object catch (error) {
      _fail(LuaHostException('Tool results could not be delivered: $error'));
      await close(terminate: true);
    }
  }

  Future<Map<String, Object?>> _dispatchOne(Map<String, Object?> call) async {
    final requestId = call['request_id']?.toString() ?? '';
    if (call['sleep_ms'] case final num milliseconds) {
      await Future<void>.delayed(
        Duration(milliseconds: milliseconds.toInt().clamp(0, 60000)),
      );
      return {'request_id': requestId, 'value': <String, Object?>{}};
    }
    final name = call['name'];
    final arguments = call['arguments'];
    if (name is! String || arguments is! Map) {
      return _toolError(requestId, 'Invalid nested tool request.');
    }
    try {
      final result = await context.dispatcher.invoke(
        LuaToolInvocation(
          name: name,
          arguments: Map<String, Object?>.from(arguments),
        ),
      );
      final descriptors = <Map<String, Object?>>[];
      for (final resource in result.resources) {
        final handle = 'resource-${_resources.length + 1}';
        _resources[handle] = resource;
        descriptors.add({
          'handle': handle,
          'file_name': resource.fileName,
          'mime_type': resource.mimeType,
          'byte_size': resource.byteSize,
        });
      }
      final enriched =
          result.resources.isNotEmpty ||
          result.content.isNotEmpty ||
          result.structuredContent != null ||
          result.meta.isNotEmpty ||
          result.isError;
      return {
        'request_id': requestId,
        'value': enriched
            ? <String, Object?>{
                'value': result.value,
                'is_error': result.isError,
                'attachments': descriptors,
                'content': result.content,
                'structured_content': result.structuredContent,
                '_meta': result.meta,
              }
            : result.value,
      };
    } on Object catch (error) {
      return _toolError(requestId, '$error');
    }
  }

  Map<String, Object?> _toolError(String requestId, String message) => {
    'request_id': requestId,
    'value': {
      'output': message,
      'is_error': true,
      'attachments': <Object?>[],
      'content': <Object?>[],
    },
  };

  void _acceptStore(Object? raw) {
    if (raw is Map) onStore(Map<String, Object?>.from(raw));
  }

  void _append(String value) {
    _output = _truncateTail(
      _output.isEmpty ? value : '$_output\n$value',
      limits.maxOutputBytes,
    );
  }

  void _protocolFailure(String message) {
    _fail(LuaProtocolException(message));
    unawaited(close(terminate: true));
  }

  void _fail(LuaRuntimeException error) {
    if (_terminal) return;
    _error = error;
    _terminal = true;
    _touch();
  }

  void _outputClosed() {
    if (!_terminal && !_closed) {
      _fail(const LuaHostException('Lua host closed its output.'));
    }
  }

  void _touch() {
    lastUsed = _clock.nowUtc();
    _revision += 1;
    if (!_changed.isCompleted) _changed.complete();
  }

  Future<LuaCellDelta<T>> read(Duration wait, int maxTokens) async {
    lastUsed = _clock.nowUtc();
    final observed = _revision;
    final changed = _changed;
    if (!_terminal && !_yielded && observed == _revision) {
      await changed.future.timeout(wait, onTimeout: () {});
    }
    if (identical(_changed, changed) && changed.isCompleted) {
      _changed = Completer<void>();
    }
    final notifications = List<Object?>.of(_notifications);
    _notifications.clear();
    return LuaCellDelta<T>(
      cellId: id,
      output: drain(maxTokens),
      running: !_terminal && !_closed,
      error: _error,
      resources: [
        for (final entry in _resources.entries)
          if (_drainedHandles.add(entry.key)) entry.value,
      ],
      emittedResources: [
        for (final handle in _emittedHandles)
          if (_drainedEmittedHandles.add(handle)) _resources[handle]!,
      ],
      notifications: notifications,
    );
  }

  String drain(int maxTokens) {
    final maximumBytes = (maxTokens * 4).clamp(1024, limits.maxOutputBytes);
    final value = _truncateTail(_output, maximumBytes);
    _output = '';
    return value;
  }

  Future<void> continueIfYielded() async {
    if (!_yielded || _terminal || _closed) return;
    _yielded = false;
    await _send('continue', const {});
  }

  Future<void> close({required bool terminate}) async {
    if (_closed) return;
    _closed = true;
    if (terminate && !_terminal) {
      try {
        await _send('terminate', const {});
      } on Object {
        // Process termination below is authoritative.
      }
    }
    _terminal = true;
    _touch();
    await _subscription.cancel();
    await _process.terminate();
    onTerminal(this);
  }
}

String _truncateTail(String value, int maxBytes) {
  final bytes = utf8.encode(value);
  if (bytes.length <= maxBytes) return value;
  var start = bytes.length - maxBytes;
  while (start < bytes.length && (bytes[start] & 0xC0) == 0x80) {
    start += 1;
  }
  return utf8.decode(bytes.sublist(start));
}
