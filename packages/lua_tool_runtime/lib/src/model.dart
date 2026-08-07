/// Current native-host protocol version.
const int luaHostProtocolVersion = 1;

/// Default upper bounds for one runtime session.
final class LuaRuntimeLimits {
  /// Creates runtime limits.
  const LuaRuntimeLimits({
    this.maxMemoryBytes = 64 * 1024 * 1024,
    this.maxSourceBytes = 256 * 1024,
    this.maxFrameBytes = 1024 * 1024,
    this.maxOutputBytes = 1024 * 1024,
    this.maxLiveCells = 8,
    this.maxYieldTime = const Duration(seconds: 60),
    this.idleTimeout = const Duration(minutes: 30),
    this.executionWatchdog = const Duration(hours: 2),
  });

  /// Native VM allocation ceiling.
  final int maxMemoryBytes;

  /// Largest accepted user chunk.
  final int maxSourceBytes;

  /// Largest protocol frame in either direction.
  final int maxFrameBytes;

  /// Buffered output ceiling per cell.
  final int maxOutputBytes;

  /// Number of live cells in one session.
  final int maxLiveCells;

  /// Longest observation period for one call.
  final Duration maxYieldTime;

  /// Time after which an unobserved cell is reclaimed.
  final Duration idleTimeout;

  /// Absolute lifetime of one cell.
  final Duration executionWatchdog;
}

/// Metadata for one callable tool.
final class LuaToolDefinition {
  /// Creates tool metadata.
  const LuaToolDefinition({
    required this.name,
    required this.description,
    this.inputSchema = const <String, Object?>{},
  });

  /// Dispatcher name.
  final String name;

  /// Human-readable behavior.
  final String description;

  /// JSON Schema for the argument table.
  final Map<String, Object?> inputSchema;
}

/// Starts a fresh Lua cell.
final class LuaExecuteRequest {
  /// Creates an execution request.
  const LuaExecuteRequest({
    required this.source,
    required this.yieldTime,
    required this.maxOutputTokens,
    this.tools = const <LuaToolDefinition>[],
  });

  /// User-authored Lua source.
  final String source;

  /// Time to observe the cell before returning a running delta.
  final Duration yieldTime;

  /// Approximate output token budget for this drain.
  final int maxOutputTokens;

  /// Tools exposed to this cell.
  final List<LuaToolDefinition> tools;
}

/// Observes, resumes, or terminates an existing cell.
final class LuaWaitRequest {
  /// Creates a wait request.
  const LuaWaitRequest({
    required this.cellId,
    required this.yieldTime,
    required this.maxOutputTokens,
    this.terminate = false,
  });

  /// Session-local cell identifier.
  final String cellId;

  /// Time to observe the cell.
  final Duration yieldTime;

  /// Approximate output token budget for this drain.
  final int maxOutputTokens;

  /// Whether to terminate rather than resume the cell.
  final bool terminate;
}

/// One nested invocation emitted by the Lua scheduler.
final class LuaToolInvocation {
  /// Creates an invocation.
  const LuaToolInvocation({required this.name, required this.arguments});

  /// Tool name.
  final String name;

  /// JSON-compatible arguments.
  final Map<String, Object?> arguments;
}

/// A value retained in Dart and represented by an opaque Lua handle.
final class LuaOpaqueResource<T extends Object> {
  /// Creates an opaque resource.
  const LuaOpaqueResource({
    required this.value,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
  });

  /// Consumer-owned value that is never serialized to Lua.
  final T value;

  /// Display file name.
  final String fileName;

  /// MIME type.
  final String mimeType;

  /// Payload size without copying the payload.
  final int byteSize;
}

/// Result of one nested tool invocation.
final class LuaToolResult<T extends Object> {
  /// Creates a tool result.
  const LuaToolResult({
    required this.output,
    this.isError = false,
    this.resources = const [],
    this.content = const <Map<String, Object?>>[],
  });

  /// Textual result.
  final String output;

  /// Whether the tool reported an error.
  final bool isError;

  /// Opaque resources made available to this cell.
  final List<LuaOpaqueResource<T>> resources;

  /// Additional JSON-compatible content blocks.
  final List<Map<String, Object?>> content;
}

/// Dispatches tools without coupling the runtime to an agent implementation.
abstract interface class LuaToolDispatcher<T extends Object> {
  /// Invokes one tool.
  Future<LuaToolResult<T>> invoke(LuaToolInvocation invocation);
}

/// Cancellation notification supplied by a consumer.
abstract interface class LuaCancellationSignal {
  /// Registers a callback invoked when the owning operation is cancelled.
  void onCancel(void Function() callback);
}

/// Per-call callbacks that may change between execute and wait.
final class LuaExecutionContext<T extends Object> {
  /// Creates an execution context.
  const LuaExecutionContext({required this.dispatcher, this.cancellation});

  /// Nested tool dispatcher.
  final LuaToolDispatcher<T> dispatcher;

  /// Optional cancellation signal.
  final LuaCancellationSignal? cancellation;
}

/// Output drained from a cell since the previous observation.
final class LuaCellDelta<T extends Object> {
  /// Creates a cell delta.
  const LuaCellDelta({
    required this.cellId,
    required this.output,
    required this.running,
    this.terminated = false,
    this.error,
    this.resources = const [],
    this.emittedResources = const [],
  });

  /// Session-local cell identifier.
  final String cellId;

  /// Text produced since the previous drain.
  final String output;

  /// Whether the cell remains live.
  final bool running;

  /// Whether the consumer explicitly terminated it.
  final bool terminated;

  /// Typed terminal failure.
  final LuaRuntimeException? error;

  /// Newly registered resources.
  final List<LuaOpaqueResource<T>> resources;

  /// Resources explicitly emitted with `image`, `audio`, or `generated_image`.
  final List<LuaOpaqueResource<T>> emittedResources;
}

/// Base type for classified Lua runtime failures.
sealed class LuaRuntimeException implements Exception {
  /// Creates a runtime failure.
  const LuaRuntimeException(this.message);

  /// Human-readable failure.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The host sent an invalid or unsafe frame.
final class LuaProtocolException extends LuaRuntimeException {
  /// Creates a protocol failure.
  const LuaProtocolException(super.message);
}

/// The native helper failed independently of the script.
final class LuaHostException extends LuaRuntimeException {
  /// Creates a host failure.
  const LuaHostException(super.message);
}

/// The user program failed to compile or run.
final class LuaScriptException extends LuaRuntimeException {
  /// Creates a script failure.
  const LuaScriptException(super.message);
}

/// A configured runtime limit was exceeded.
final class LuaLimitException extends LuaRuntimeException {
  /// Creates a limit failure.
  const LuaLimitException(super.message);
}

/// A requested cell does not exist in the session.
final class LuaCellNotFoundException extends LuaRuntimeException {
  /// Creates a missing-cell failure.
  const LuaCellNotFoundException(super.message);
}
