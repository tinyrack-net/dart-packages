import 'program_bundle.dart';

/// Current native-host protocol version.
const int luaHostProtocolVersion = 2;

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
    this.maxWallTime = const Duration(hours: 2),
    this.maxInstructions = 100000000,
    this.instructionHookInterval = 10000,
    this.maxWorkersPerRevision = 2,
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

  /// Wall-clock deadline for one invocation, including host awaits.
  final Duration maxWallTime;

  /// Approximate maximum Lua VM instructions for one fresh invocation.
  final int maxInstructions;

  /// Native instruction-hook sampling interval.
  final int instructionHookInterval;

  /// Maximum simultaneous native workers for one program revision.
  final int maxWorkersPerRevision;
}

/// Metadata for one callable tool.
final class LuaToolDefinition {
  /// Creates tool metadata.
  const LuaToolDefinition({
    required this.name,
    required this.description,
    this.kind = 'function',
    this.namespace,
    this.exposure = 'nested',
    this.inputSchema = const <String, Object?>{},
    this.outputSchema,
  });

  /// Dispatcher name.
  final String name;

  /// Human-readable behavior.
  final String description;

  /// Wire-level tool kind.
  final String kind;

  /// Provider namespace, when the tool is namespaced.
  final String? namespace;

  /// How the owning harness exposes this tool.
  final String exposure;

  /// JSON Schema for the argument table.
  final Map<String, Object?> inputSchema;

  /// JSON Schema produced by the tool, when declared.
  final Map<String, Object?>? outputSchema;
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

/// Invokes one named handler from an immutable program bundle.
final class LuaInvokeRequest {
  /// Creates a named handler invocation.
  const LuaInvokeRequest({
    required this.bundle,
    required this.handler,
    required this.yieldTime,
    required this.maxOutputTokens,
    this.arguments = const <String, Object?>{},
    this.tools = const <LuaToolDefinition>[],
  });

  /// Revision-pinned code and Markdown assets.
  final LuaProgramBundle bundle;

  /// Entrypoint table key to invoke.
  final String handler;

  /// JSON-compatible handler argument object.
  final Map<String, Object?> arguments;

  /// Time to observe the cell before returning a running delta.
  final Duration yieldTime;

  /// Approximate output token budget for this drain.
  final int maxOutputTokens;

  /// Tools exposed to this invocation.
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
  const LuaToolInvocation({
    required this.name,
    required this.arguments,
    this.cancellation,
  });

  /// Tool name.
  final String name;

  /// JSON-compatible arguments.
  final Map<String, Object?> arguments;

  /// Cancellation token scoped to the owning Lua invocation.
  final LuaInvocationCancellation? cancellation;
}

/// One generic host callback emitted by Lua.
final class LuaHostInvocation {
  /// Creates a host callback invocation.
  const LuaHostInvocation({
    required this.name,
    required this.arguments,
    required this.cancellation,
  });

  /// Consumer-defined callback name.
  final String name;

  /// JSON-compatible callback arguments.
  final Map<String, Object?> arguments;

  /// Cancellation token scoped to the owning Lua invocation.
  final LuaInvocationCancellation cancellation;
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
    required this.value,
    this.isError = false,
    this.resources = const [],
    this.content = const <Map<String, Object?>>[],
    this.structuredContent,
    this.meta = const <String, Object?>{},
  });

  /// Natural string, scalar, list, or object returned to Lua.
  final Object? value;

  /// Whether the tool reported an error.
  final bool isError;

  /// Opaque resources made available to this cell.
  final List<LuaOpaqueResource<T>> resources;

  /// Additional JSON-compatible content blocks.
  final List<Map<String, Object?>> content;

  /// Provider-owned structured result.
  final Object? structuredContent;

  /// Provider metadata retained with the result.
  final Map<String, Object?> meta;
}

/// Result or stream event returned by a generic host callback.
final class LuaHostResult<T extends Object> {
  /// Creates a host result.
  const LuaHostResult({
    required this.value,
    this.isError = false,
    this.resources = const [],
  });

  /// JSON-compatible value returned to Lua.
  final Object? value;

  /// Whether the callback reported an application error.
  final bool isError;

  /// Opaque resources registered with the invocation.
  final List<LuaOpaqueResource<T>> resources;
}

/// Dispatches tools without coupling the runtime to an agent implementation.
abstract interface class LuaToolDispatcher<T extends Object> {
  /// Invokes one tool.
  Future<LuaToolResult<T>> invoke(LuaToolInvocation invocation);
}

/// Dispatches generic unary callbacks and pull-based event streams.
///
/// Product runtimes can expose provider-neutral model streams and capability
/// broker operations through this port without adding privileged Lua globals.
abstract interface class LuaHostCallbackDispatcher<T extends Object> {
  /// Executes one unary host callback.
  Future<LuaHostResult<T>> call(LuaHostInvocation invocation);

  /// Opens one callback event stream. Lua consumes it with `host.next`.
  Stream<LuaHostResult<T>> open(LuaHostInvocation invocation);
}

/// Cancellation state shared with in-flight host and tool callbacks.
abstract interface class LuaInvocationCancellation {
  /// Whether the owning invocation was cancelled.
  bool get isCancelled;

  /// Registers a callback fired once on cancellation.
  void onCancel(void Function() callback);
}

/// Cancellation notification supplied by a consumer.
abstract interface class LuaCancellationSignal {
  /// Registers a callback invoked when the owning operation is cancelled.
  void onCancel(void Function() callback);
}

/// Per-call callbacks that may change between execute and wait.
final class LuaExecutionContext<T extends Object> {
  /// Creates an execution context.
  const LuaExecutionContext({
    required this.dispatcher,
    this.hostCallbacks,
    this.cancellation,
  });

  /// Nested tool dispatcher.
  final LuaToolDispatcher<T> dispatcher;

  /// Optional generic host callback and stream dispatcher.
  final LuaHostCallbackDispatcher<T>? hostCallbacks;

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
    this.notifications = const <Object?>[],
    this.result,
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

  /// Immediate notification values drained separately from normal output.
  final List<Object?> notifications;

  /// Final JSON-compatible named-handler return value.
  final Object? result;
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

/// The owning consumer cancelled an invocation.
final class LuaCancelledException extends LuaRuntimeException {
  /// Creates a cancellation failure.
  const LuaCancelledException(super.message);
}
