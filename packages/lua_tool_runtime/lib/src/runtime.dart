import 'dart:async';
import 'dart:convert';

import 'model.dart';
import 'process.dart';
import 'program_bundle.dart';

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

  /// Creates a session with isolated store, cells, resources, and workers.
  LuaRuntimeSession<T> createSession({
    LuaRuntimeLimits limits = const LuaRuntimeLimits(),
  }) {
    _validateRuntimeLimits(limits);
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

void _validateRuntimeLimits(LuaRuntimeLimits limits) {
  if (limits.maxMemoryBytes < 1024 * 1024 ||
      limits.maxSourceBytes <= 0 ||
      limits.maxFrameBytes <= 0 ||
      limits.maxOutputBytes <= 0 ||
      limits.maxLiveCells <= 0 ||
      limits.maxYieldTime <= Duration.zero ||
      limits.idleTimeout <= Duration.zero ||
      limits.executionWatchdog <= Duration.zero ||
      limits.maxWallTime <= Duration.zero ||
      limits.maxInstructions < 1000 ||
      limits.instructionHookInterval < 100 ||
      limits.maxWorkersPerRevision <= 0) {
    throw ArgumentError.value(
      limits,
      'limits',
      'Runtime limits must be positive.',
    );
  }
}

/// Session-isolated invocation collection, JSON store, and revision workers.
final class LuaRuntimeSession<T extends Object> {
  LuaRuntimeSession._(this._runtime, this.limits);

  final LuaToolRuntime<T> _runtime;

  /// Limits applied to invocations in this session.
  final LuaRuntimeLimits limits;

  final Map<String, _LuaCell<T>> _cells = {};
  final Map<_LuaWorkerKey, List<_LuaWorker<T>>> _workers = {};
  final Map<String, String> _revisionIdentities = {};
  Future<void> _workerQueue = Future<void>.value();
  Map<String, Object?> _store = {};
  int _pendingInvocations = 0;
  bool _closed = false;

  /// Snapshot of the JSON-serializable session store.
  Map<String, Object?> get store => Map.unmodifiable(_store);

  /// Starts an inline source chunk in a fresh VM.
  ///
  /// New plugin hosts should prefer [invoke]. This convenience API is retained
  /// for code-mode integrations and is implemented as a named bundle handler.
  Future<LuaCellDelta<T>> execute(
    LuaExecuteRequest request,
    LuaExecutionContext<T> context, {
    String workingDirectory = '.',
  }) {
    final module =
        'return {run = function(_arguments)\n${request.source}\nend}';
    return invoke(
      LuaInvokeRequest(
        bundle: LuaProgramBundle(
          revision: 'inline:${_fnv1a64(request.source)}',
          entrypoint: 'main',
          modules: {'main': module},
        ),
        handler: 'run',
        yieldTime: request.yieldTime,
        maxOutputTokens: request.maxOutputTokens,
        tools: request.tools,
      ),
      context,
      workingDirectory: workingDirectory,
    );
  }

  /// Invokes a named handler in a fresh Lua VM.
  ///
  /// Native helper processes are lazily reused by revision, but the helper
  /// discards the previous VM before accepting another invocation.
  Future<LuaCellDelta<T>> invoke(
    LuaInvokeRequest request,
    LuaExecutionContext<T> context, {
    String workingDirectory = '.',
  }) async {
    if (_closed) throw StateError('Lua runtime session is closed.');
    if (!_validHandler.hasMatch(request.handler)) {
      return LuaCellDelta<T>(
        cellId: '',
        output: '',
        running: false,
        error: LuaProtocolException(
          'Invalid Lua handler name: ${request.handler}',
        ),
      );
    }
    if (request.bundle.encodedByteLength > limits.maxSourceBytes) {
      return LuaCellDelta<T>(
        cellId: '',
        output: '',
        running: false,
        error: LuaLimitException(
          'Lua bundle exceeds ${limits.maxSourceBytes} bytes.',
        ),
      );
    }
    try {
      jsonEncode(request.arguments);
    } on Object catch (error) {
      return LuaCellDelta<T>(
        cellId: '',
        output: '',
        running: false,
        error: LuaProtocolException('Handler arguments are not JSON: $error'),
      );
    }
    final knownIdentity = _revisionIdentities[request.bundle.revision];
    if (knownIdentity != null &&
        knownIdentity != request.bundle.contentIdentity) {
      return LuaCellDelta<T>(
        cellId: '',
        output: '',
        running: false,
        error: LuaProtocolException(
          'Bundle revision ${request.bundle.revision} changed content.',
        ),
      );
    }
    _revisionIdentities[request.bundle.revision] =
        request.bundle.contentIdentity;

    sweep();
    _LuaCell<T>? oldest;
    if (_cells.length + _pendingInvocations >= limits.maxLiveCells) {
      if (_pendingInvocations > 0 || _cells.isEmpty) {
        return LuaCellDelta<T>(
          cellId: '',
          output: '',
          running: false,
          error: LuaLimitException(
            'Lua session already has ${limits.maxLiveCells} live invocations.',
          ),
        );
      }
      oldest = _cells.values.reduce(
        (left, right) => left.lastUsed.isBefore(right.lastUsed) ? left : right,
      );
    }
    _pendingInvocations += 1;
    late final _LuaCell<T> cell;
    try {
      if (oldest != null) await _remove(oldest, terminate: true);
      final key = _LuaWorkerKey(request.bundle.revision, workingDirectory);
      final worker = await _acquireWorker(key);
      if (worker == null) {
        return LuaCellDelta<T>(
          cellId: '',
          output: '',
          running: false,
          error: LuaLimitException(
            'Revision ${request.bundle.revision} already has '
            '${limits.maxWorkersPerRevision} live workers.',
          ),
        );
      }
      if (_closed) {
        await worker.close();
        throw StateError('Lua runtime session is closed.');
      }
      final id = 'lua-${_runtime.ids.generate()}';
      cell = _LuaCell<T>(
        id: id,
        worker: worker,
        clock: _runtime.clock,
        limits: limits,
        context: context,
        onStore: (value) => _store = value,
        onAbort: () => unawaited(_remove(cell, terminate: true)),
      );
      worker.attach(cell);
      _cells[id] = cell;
    } finally {
      _pendingInvocations -= 1;
    }
    try {
      await cell.initialize(request, _store);
    } on Object {
      await _remove(cell, terminate: true);
      rethrow;
    }
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
      final output = cell.drain(request.maxOutputTokens);
      await _remove(cell, terminate: true);
      return LuaCellDelta<T>(
        cellId: request.cellId,
        output: output,
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

  Future<_LuaWorker<T>?> _acquireWorker(_LuaWorkerKey key) async {
    final previous = _workerQueue;
    final release = Completer<void>();
    _workerQueue = release.future;
    await previous;
    try {
      return await _acquireWorkerUnlocked(key);
    } finally {
      release.complete();
    }
  }

  Future<_LuaWorker<T>?> _acquireWorkerUnlocked(_LuaWorkerKey key) async {
    final workers = _workers.putIfAbsent(key, () => []);
    for (final worker in workers) {
      if (!worker.isDead && worker.isIdle) {
        worker.reserve();
        return worker;
      }
    }
    workers.removeWhere((worker) => worker.isDead);
    if (workers.length >= limits.maxWorkersPerRevision) return null;
    final process = await _runtime.processLauncher.start(
      _runtime.host.withEnvironment({
        'LUA_TOOL_RUNTIME_MEMORY_LIMIT_BYTES': '${limits.maxMemoryBytes}',
        'LUA_TOOL_RUNTIME_INSTRUCTION_LIMIT': '${limits.maxInstructions}',
        'LUA_TOOL_RUNTIME_HOOK_INTERVAL': '${limits.instructionHookInterval}',
      }),
      workingDirectory: key.workingDirectory,
    );
    late final _LuaWorker<T> worker;
    worker = _LuaWorker<T>(
      process,
      onDead: () {
        workers.remove(worker);
        if (workers.isEmpty) _workers.remove(key);
      },
    );
    workers.add(worker);
    worker.reserve();
    return worker;
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

  /// Terminates all cells and revision workers in this session.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(
      List<_LuaCell<T>>.of(
        _cells.values,
      ).map((cell) => _remove(cell, terminate: true)),
    );
    await _workerQueue;
    final workers = <_LuaWorker<T>>{
      for (final group in _workers.values) ...group,
    };
    await Future.wait(workers.map((worker) => worker.close()));
    _workers.clear();
    _runtime._forget(this);
  }

  Future<void> _remove(_LuaCell<T> cell, {required bool terminate}) async {
    _cells.remove(cell.id);
    await cell.close(terminate: terminate);
  }
}

final class _LuaWorkerKey {
  const _LuaWorkerKey(this.revision, this.workingDirectory);

  final String revision;
  final String workingDirectory;

  @override
  bool operator ==(Object other) =>
      other is _LuaWorkerKey &&
      other.revision == revision &&
      other.workingDirectory == workingDirectory;

  @override
  int get hashCode => Object.hash(revision, workingDirectory);
}

final class _LuaWorker<T extends Object> {
  _LuaWorker(this._process, {required this.onDead}) {
    _subscription = _process.outputs.listen(
      (data) => _cell?._receiveData(data),
      onError: (Object error, StackTrace stack) {
        _cell?._hostFailed(LuaHostException('$error'));
        unawaited(close());
      },
      onDone: () {
        _cell?._hostFailed(
          const LuaHostException('Lua host closed its output.'),
        );
        unawaited(close());
      },
    );
    unawaited(
      _process.exitCode.then<void>(
        (code) {
          if (!_dead && code != 0) {
            _cell?._hostFailed(
              LuaHostException('Lua host exited with code $code.'),
            );
            unawaited(close());
          }
        },
        onError: (Object error) {
          _cell?._hostFailed(LuaHostException('Lua host crashed: $error'));
          unawaited(close());
        },
      ),
    );
  }

  final LuaHostProcess _process;
  final void Function() onDead;
  late final StreamSubscription<String> _subscription;
  _LuaCell<T>? _cell;
  bool _reserved = false;
  bool _dead = false;

  bool get isDead => _dead;
  bool get isIdle => _cell == null && !_reserved;

  void reserve() {
    if (_dead || !isIdle) throw StateError('Lua worker is not available.');
    _reserved = true;
  }

  void attach(_LuaCell<T> cell) {
    if (_dead || _cell != null || !_reserved) {
      throw StateError('Lua worker is not available.');
    }
    _reserved = false;
    _cell = cell;
  }

  void release(_LuaCell<T> cell) {
    if (identical(_cell, cell)) _cell = null;
  }

  Future<void> write(String value) => _process.write(value);

  Future<void> close() async {
    if (_dead) return;
    _dead = true;
    final active = _cell;
    _cell = null;
    active?._hostFailed(const LuaHostException('Lua worker was terminated.'));
    await _process.terminate();
    await _subscription.cancel();
    onDead();
  }
}

final class _LuaCell<T extends Object> {
  _LuaCell({
    required this.id,
    required this.worker,
    required LuaClock clock,
    required this.limits,
    required this.context,
    required this.onStore,
    required this.onAbort,
  }) : _clock = clock,
       startedAt = clock.nowUtc(),
       lastUsed = clock.nowUtc() {
    _wallTimer = Timer(limits.maxWallTime, () {
      _fail(
        LuaLimitException(
          'Lua invocation exceeded ${limits.maxWallTime.inMilliseconds} ms.',
        ),
      );
      onAbort();
    });
    bindCancellation();
  }

  final String id;
  final _LuaWorker<T> worker;
  final LuaClock _clock;
  final LuaRuntimeLimits limits;
  final void Function(Map<String, Object?>) onStore;
  final void Function() onAbort;
  final Map<String, LuaOpaqueResource<T>> _resources = {};
  final Map<String, StreamIterator<LuaHostResult<T>>> _hostStreams = {};
  final Set<String> _emittedHandles = {};
  final Set<String> _drainedHandles = {};
  final Set<String> _drainedEmittedHandles = {};
  final List<Object?> _notifications = [];
  final _LuaInvocationCancellationController _invocationCancellation =
      _LuaInvocationCancellationController();
  late final Timer _wallTimer;
  LuaExecutionContext<T> context;
  final DateTime startedAt;
  DateTime lastUsed;
  String _inputBuffer = '';
  String _output = '';
  Object? _result;
  LuaRuntimeException? _error;
  bool _terminal = false;
  bool _yielded = false;
  bool _closed = false;
  int _expectedSequence = 1;
  int _outboundSequence = 0;
  int _revision = 0;
  int _cancellationGeneration = 0;
  int _nextStream = 0;
  Completer<void> _changed = Completer<void>();

  void bindCancellation() {
    final generation = ++_cancellationGeneration;
    context.cancellation?.onCancel(() {
      if (generation == _cancellationGeneration && !_closed) {
        _fail(const LuaCancelledException('Lua invocation was cancelled.'));
        onAbort();
      }
    });
  }

  Future<void> initialize(
    LuaInvokeRequest request,
    Map<String, Object?> store,
  ) => _send('invoke', {
    'bundle': {
      'revision': request.bundle.revision,
      'entrypoint': request.bundle.entrypoint,
      'modules': request.bundle.modules,
      'preload_modules': request.bundle.preloadModules,
      'markdown_assets': request.bundle.markdownAssets,
    },
    'handler': request.handler,
    'arguments': request.arguments,
    'tools': [
      for (final tool in request.tools)
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
    await worker.write('$encoded\n');
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
      case 'callback_batch':
        unawaited(_dispatchBatch(payload, responseType: 'callback_results'));
      case 'tool_batch':
        unawaited(_dispatchBatch(payload, responseType: 'tool_results'));
      case 'yielded':
        _yielded = true;
        _acceptStore(payload['store']);
        _touch();
      case 'completed':
      case 'terminated':
        _acceptStore(payload['store']);
        _result = payload['result'];
        _terminal = true;
        _wallTimer.cancel();
        _touch();
      case 'error':
        _acceptStore(payload['store']);
        final message =
            payload['message']?.toString() ?? 'Unknown Lua script error.';
        final category = payload['category']?.toString();
        _fail(
          category == 'limit' || message.contains('__LUA_LIMIT_')
              ? LuaLimitException(message)
              : LuaScriptException(message),
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

  Future<void> _dispatchBatch(
    Map<String, Object?> payload, {
    required String responseType,
  }) async {
    final rawCalls = payload['calls'];
    if (rawCalls is! List) {
      _protocolFailure('Invalid callback batch.');
      return;
    }
    try {
      final results = await Future.wait([
        for (final raw in rawCalls)
          _dispatchOne(Map<String, Object?>.from(raw! as Map)),
      ]);
      if (!_closed) await _send(responseType, {'results': results});
    } on Object catch (error) {
      if (_closed) return;
      _fail(
        LuaHostException('Callback results could not be delivered: $error'),
      );
      onAbort();
    }
  }

  Future<Map<String, Object?>> _dispatchOne(Map<String, Object?> call) async {
    final requestId = call['request_id']?.toString() ?? '';
    if (call['sleep_ms'] case final num milliseconds) {
      await _invocationCancellation.race(
        Future<void>.delayed(
          Duration(milliseconds: milliseconds.toInt().clamp(0, 60000)),
        ),
      );
      return {'request_id': requestId, 'value': <String, Object?>{}};
    }
    final operation = call['operation']?.toString() ?? 'tool_call';
    switch (operation) {
      case 'tool_call':
        return _dispatchTool(requestId, call);
      case 'host_call':
        return _dispatchHostCall(requestId, call);
      case 'host_open':
        return _openHostStream(requestId, call);
      case 'host_next':
        return _nextHostStream(requestId, call);
      case 'host_close':
        return _closeHostStream(requestId, call);
      default:
        return _toolError(requestId, 'Unknown callback operation: $operation');
    }
  }

  Future<Map<String, Object?>> _dispatchTool(
    String requestId,
    Map<String, Object?> call,
  ) async {
    final name = call['name'];
    final arguments = _decodeArguments(call['arguments']);
    if (name is! String || arguments == null) {
      return _toolError(requestId, 'Invalid nested tool request.');
    }
    try {
      final result = await _invocationCancellation.race(
        context.dispatcher.invoke(
          LuaToolInvocation(
            name: name,
            arguments: arguments,
            cancellation: _invocationCancellation,
          ),
        ),
      );
      return {'request_id': requestId, 'value': _encodeToolResult(result)};
    } on Object catch (error) {
      return _toolError(requestId, '$error');
    }
  }

  Future<Map<String, Object?>> _dispatchHostCall(
    String requestId,
    Map<String, Object?> call,
  ) async {
    final invocation = _hostInvocation(call);
    final callbacks = context.hostCallbacks;
    if (invocation == null || callbacks == null) {
      return _toolError(requestId, 'Host callback is unavailable.');
    }
    try {
      final result = await _invocationCancellation.race(
        callbacks.call(invocation),
      );
      return {'request_id': requestId, 'value': _encodeHostResult(result)};
    } on Object catch (error) {
      return _toolError(requestId, '$error');
    }
  }

  Future<Map<String, Object?>> _openHostStream(
    String requestId,
    Map<String, Object?> call,
  ) async {
    final invocation = _hostInvocation(call);
    final callbacks = context.hostCallbacks;
    if (invocation == null || callbacks == null) {
      return _toolError(requestId, 'Host stream callback is unavailable.');
    }
    try {
      final handle = 'stream-${++_nextStream}';
      _hostStreams[handle] = StreamIterator(callbacks.open(invocation));
      return {'request_id': requestId, 'value': handle};
    } on Object catch (error) {
      return _toolError(requestId, '$error');
    }
  }

  Future<Map<String, Object?>> _nextHostStream(
    String requestId,
    Map<String, Object?> call,
  ) async {
    final handle = call['stream_handle'];
    final iterator = handle is String ? _hostStreams[handle] : null;
    if (iterator == null) {
      return _toolError(requestId, 'Unknown host stream handle.');
    }
    try {
      if (!await _invocationCancellation.race(iterator.moveNext())) {
        _hostStreams.remove(handle);
        await iterator.cancel();
        return {
          'request_id': requestId,
          'value': {'done': true},
        };
      }
      return {
        'request_id': requestId,
        'value': {'done': false, 'value': _encodeHostResult(iterator.current)},
      };
    } on Object catch (error) {
      _hostStreams.remove(handle);
      await iterator.cancel();
      return _toolError(requestId, '$error');
    }
  }

  Future<Map<String, Object?>> _closeHostStream(
    String requestId,
    Map<String, Object?> call,
  ) async {
    final handle = call['stream_handle'];
    final iterator = handle is String ? _hostStreams.remove(handle) : null;
    if (iterator == null) {
      return _toolError(requestId, 'Unknown host stream handle.');
    }
    await iterator.cancel();
    return {'request_id': requestId, 'value': true};
  }

  LuaHostInvocation? _hostInvocation(Map<String, Object?> call) {
    final name = call['name'];
    final arguments = _decodeArguments(call['arguments']);
    if (name is! String || arguments == null) return null;
    return LuaHostInvocation(
      name: name,
      arguments: arguments,
      cancellation: _invocationCancellation,
    );
  }

  Object? _encodeToolResult(LuaToolResult<T> result) {
    final descriptors = _registerResources(result.resources);
    final enriched =
        result.resources.isNotEmpty ||
        result.content.isNotEmpty ||
        result.structuredContent != null ||
        result.meta.isNotEmpty ||
        result.isError;
    return enriched
        ? <String, Object?>{
            'value': result.value,
            'is_error': result.isError,
            'attachments': descriptors,
            'content': result.content,
            'structured_content': result.structuredContent,
            '_meta': result.meta,
          }
        : result.value;
  }

  Object? _encodeHostResult(LuaHostResult<T> result) {
    final descriptors = _registerResources(result.resources);
    if (descriptors.isEmpty && !result.isError) return result.value;
    return <String, Object?>{
      'value': result.value,
      'is_error': result.isError,
      'attachments': descriptors,
    };
  }

  List<Map<String, Object?>> _registerResources(
    List<LuaOpaqueResource<T>> resources,
  ) {
    final descriptors = <Map<String, Object?>>[];
    for (final resource in resources) {
      final handle = 'resource-${_resources.length + 1}';
      _resources[handle] = resource;
      descriptors.add({
        'handle': handle,
        'file_name': resource.fileName,
        'mime_type': resource.mimeType,
        'byte_size': resource.byteSize,
      });
    }
    return descriptors;
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
    onAbort();
  }

  void _hostFailed(LuaHostException error) {
    if (_terminal || _closed) return;
    _fail(error);
  }

  void _fail(LuaRuntimeException error) {
    if (_terminal) return;
    _error = error;
    _terminal = true;
    _wallTimer.cancel();
    _touch();
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
      result: _result,
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
    _wallTimer.cancel();
    if (terminate) _invocationCancellation.cancel();
    if (terminate && !_terminal && !worker.isDead) {
      try {
        await _send('terminate', const {});
      } on Object {
        // Worker termination below is authoritative.
      }
    }
    _terminal = true;
    _touch();
    if (_hostStreams.isNotEmpty) {
      await Future.wait(
        _hostStreams.values.map((iterator) => iterator.cancel()),
      );
    }
    _hostStreams.clear();
    if (terminate) {
      await worker.close();
    } else {
      worker.release(this);
    }
  }
}

Map<String, Object?>? _decodeArguments(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  if (value is List && value.isEmpty) return <String, Object?>{};
  return null;
}

final class _LuaInvocationCancellationController
    implements LuaInvocationCancellation {
  final List<void Function()> _callbacks = [];
  final Completer<void> _cancelledSignal = Completer<void>();
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;

  @override
  void onCancel(void Function() callback) {
    if (_cancelled) {
      _notify(callback);
    } else {
      _callbacks.add(callback);
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledSignal.complete();
    final callbacks = List<void Function()>.of(_callbacks);
    _callbacks.clear();
    for (final callback in callbacks) {
      _notify(callback);
    }
  }

  void _notify(void Function() callback) {
    try {
      callback();
    } on Object {
      // A consumer cleanup callback cannot prevent authoritative cancellation.
    }
  }

  Future<R> race<R>(Future<R> operation) {
    if (_cancelled) {
      return Future<R>.error(
        const LuaCancelledException('Lua invocation was cancelled.'),
      );
    }
    return Future.any<R>([
      operation,
      _cancelledSignal.future.then<R>(
        (_) =>
            throw const LuaCancelledException('Lua invocation was cancelled.'),
      ),
    ]);
  }
}

final RegExp _validHandler = RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$');

String _fnv1a64(String source) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(source)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
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
