@Tags(['host'])
library;

import 'dart:async';
import 'dart:io';

import 'package:lua_tool_runtime/lua_tool_runtime.dart';
import 'package:test/test.dart';

void main() {
  late Directory distributionDirectory;
  late Directory buildDirectory;
  late LuaHostCommand command;

  setUpAll(() async {
    distributionDirectory = await Directory.systemTemp.createTemp(
      'lua-tool-runtime-contract-',
    );
    buildDirectory = await Directory.systemTemp.createTemp(
      'lua-tool-runtime-build-',
    );
    final distribution = await stageLuaToolRuntime(
      destination: distributionDirectory.path,
      buildMode: LuaBuildMode.debug,
      buildDirectory: buildDirectory.path,
    );
    command = LuaHostCommand(
      executable: distribution.hostPath,
      arguments: [distribution.bootstrapPath],
    );
  });

  tearDownAll(() async {
    await distributionDirectory.delete(recursive: true);
    await buildDirectory.delete(recursive: true);
  });

  test('runs parallel tools in a sandbox and retains JSON null', () async {
    final dispatcher = ParallelDispatcher();
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession();
    final context = LuaExecutionContext<String>(dispatcher: dispatcher);
    var delta = await session.execute(
      const LuaExecuteRequest(
        source: '''
local first = spawn(function() return tools.echo({value="a"}) end)
local second = spawn(function() return tools.echo({value="b"}) end)
local values = await_all({first, second})
text(values[1][1] .. values[2][1])
text(tostring(io) .. ":" .. tostring(os) .. ":" .. tostring(package))
store("null-value", NULL)
local cyclic = {}; cyclic.self = cyclic
text(tostring(pcall(function() store("cyclic", cyclic) end)))
''',
        tools: [LuaToolDefinition(name: 'echo', description: 'Echo')],
        yieldTime: Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    final output = StringBuffer(delta.output);
    while (delta.running) {
      delta = await session.wait(
        LuaWaitRequest(
          cellId: delta.cellId,
          yieldTime: const Duration(seconds: 5),
          maxOutputTokens: 1000,
        ),
        context,
      );
      if (delta.output.isNotEmpty) output.writeln(delta.output);
    }

    expect(output.toString(), contains('ab'));
    expect(output.toString(), contains('nil:nil:nil'));
    expect(output.toString(), contains('false'));
    expect(dispatcher.maximumActive, 2);

    final stored = await session.execute(
      const LuaExecuteRequest(
        source: 'text(tostring(load("null-value")))',
        yieldTime: Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    expect(stored.output, contains('null'));
  });

  test(
    'pending timers do not keep an otherwise completed cell alive',
    () async {
      final runtime = _runtime(command);
      addTearDown(runtime.close);
      final session = runtime.createSession();
      final elapsed = Stopwatch()..start();
      var delta = await session.execute(
        const LuaExecuteRequest(
          source: '''
set_timeout(function() text("late") end, 60000)
text("done")
''',
          yieldTime: Duration(seconds: 5),
          maxOutputTokens: 1000,
        ),
        LuaExecutionContext(dispatcher: ParallelDispatcher()),
        workingDirectory: Directory.current.path,
      );
      final output = StringBuffer(delta.output);
      while (delta.running) {
        delta = await session.wait(
          LuaWaitRequest(
            cellId: delta.cellId,
            yieldTime: const Duration(seconds: 1),
            maxOutputTokens: 1000,
          ),
          LuaExecutionContext(dispatcher: ParallelDispatcher()),
        );
        output.write(delta.output);
      }
      expect(delta.running, isFalse);
      expect(output.toString(), contains('done'));
      expect(output.toString(), isNot(contains('late')));
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 10)));
    },
  );

  test('classifies compile errors and memory exhaustion', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession(
      limits: const LuaRuntimeLimits(maxMemoryBytes: 2 * 1024 * 1024),
    );
    final context = LuaExecutionContext<String>(
      dispatcher: ParallelDispatcher(),
    );
    final compile = await session.execute(
      const LuaExecuteRequest(
        source: 'this is not lua',
        yieldTime: Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    expect(compile.error, isA<LuaScriptException>());

    final memory = await session.execute(
      const LuaExecuteRequest(
        source: '''
local values = {}
while true do values[#values + 1] = string.rep("x", 65536) end
''',
        yieldTime: Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    expect(memory.error, isA<LuaScriptException>());
    expect(memory.error!.message.toLowerCase(), contains('memory'));
  });

  test('loads safe modules and Markdown assets for a named handler', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession();
    final context = LuaExecutionContext<String>(
      dispatcher: ParallelDispatcher(),
    );
    var delta = await session.invoke(
      LuaInvokeRequest(
        bundle: LuaProgramBundle(
          revision: 'sha256:assets',
          entrypoint: 'main',
          modules: const {
            'tinest.sdk': '''
tinest = {prefix = "Safe"}
return tinest
''',
            'main': '''
local helper = require("plugin.helper")
return {run = function(input)
  text(tinest.prefix .. ":" .. assets.read("prompts/system.md"))
  return helper.answer + input.increment
end}
''',
            'plugin.helper': 'return {answer = 40}',
          },
          preloadModules: const ['tinest.sdk'],
          markdownAssets: const {'prompts/system.md': '# Safe prompt'},
        ),
        handler: 'run',
        arguments: const {'increment': 2},
        yieldTime: const Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    final output = StringBuffer(delta.output);
    while (delta.running) {
      delta = await session.wait(
        LuaWaitRequest(
          cellId: delta.cellId,
          yieldTime: const Duration(seconds: 5),
          maxOutputTokens: 1000,
        ),
        context,
      );
      output.write(delta.output);
    }

    expect(delta.error, isNull);
    expect(output.toString(), contains('Safe:# Safe prompt'));
    expect(delta.result, 42);
  });

  test('reuses a helper with fresh VMs and streams host events', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession();
    final callbacks = ContractCallbacks();
    final context = LuaExecutionContext<String>(
      dispatcher: ParallelDispatcher(),
      hostCallbacks: callbacks,
    );
    final bundle = LuaProgramBundle(
      revision: 'sha256:fresh-stream',
      entrypoint: 'main',
      modules: const {
        'main': '''
return {run = function()
  local previous = _G.invocation_marker
  _G.invocation_marker = true
  local unary = host.call("model.describe", {})
  local stream = host.open("model.events", {})
  local event = host.next(stream)
  host.close(stream)
  return {previous = previous or false, unary = unary, event = event.value}
end}
''',
      },
    );

    Future<LuaCellDelta<String>> run() => session.invoke(
      LuaInvokeRequest(
        bundle: bundle,
        handler: 'run',
        yieldTime: const Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );

    final first = await run();
    final second = await run();
    expect(first.error, isNull);
    expect(second.error, isNull);
    expect(first.result, {
      'previous': false,
      'unary': {'model': 'test'},
      'event': {'type': 'text_delta', 'text': 'hello'},
    });
    expect(second.result, first.result);
    expect(callbacks.calls, 2);
    expect(callbacks.streams, 2);
  });

  test('wall deadline cancels an in-flight host await', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession(
      limits: const LuaRuntimeLimits(maxWallTime: Duration(milliseconds: 100)),
    );
    final callbacks = HangingCallbacks();
    final delta = await session.invoke(
      LuaInvokeRequest(
        bundle: LuaProgramBundle(
          revision: 'sha256:host-await',
          entrypoint: 'main',
          modules: const {
            'main': '''
return {run = function() return host.call("never", {}) end}
''',
          },
        ),
        handler: 'run',
        yieldTime: const Duration(seconds: 2),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(
        dispatcher: ParallelDispatcher(),
        hostCallbacks: callbacks,
      ),
      workingDirectory: Directory.current.path,
    );

    expect(delta.error, isA<LuaLimitException>());
    expect(callbacks.cancelled, isTrue);
  });

  test('stops compute with an instruction budget and wall deadline', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession(
      limits: const LuaRuntimeLimits(
        maxInstructions: 250000,
        maxWallTime: Duration(seconds: 2),
      ),
    );
    final elapsed = Stopwatch()..start();
    final delta = await session.invoke(
      LuaInvokeRequest(
        bundle: LuaProgramBundle(
          revision: 'sha256:loop',
          entrypoint: 'main',
          modules: const {
            'main': 'return {run = function() while true do end end}',
          },
        ),
        handler: 'run',
        yieldTime: const Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: ParallelDispatcher()),
      workingDirectory: Directory.current.path,
    );

    expect(delta.error, isA<LuaLimitException>());
    expect(elapsed.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('privileged protocol work does not consume the user budget', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession(
      limits: const LuaRuntimeLimits(maxInstructions: 250000),
    );
    final context = LuaExecutionContext<String>(
      dispatcher: ParallelDispatcher(),
      hostCallbacks: EchoCallbacks(4096),
    );
    // The handler itself costs a few thousand instructions. Decoding two
    // hundred 4 KiB callback results costs millions, and all of it runs in the
    // privileged bootstrap chunk, where a budget trip is unprotected.
    var delta = await session.invoke(
      LuaInvokeRequest(
        bundle: LuaProgramBundle(
          revision: 'sha256:chatty',
          entrypoint: 'main',
          modules: const {
            'main': '''
return {run = function()
  local total = 0
  for _ = 1, 200 do total = total + #host.call("echo", {}) end
  return total
end}
''',
          },
        ),
        handler: 'run',
        yieldTime: const Duration(seconds: 10),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    while (delta.running) {
      delta = await session.wait(
        LuaWaitRequest(
          cellId: delta.cellId,
          yieldTime: const Duration(seconds: 10),
          maxOutputTokens: 1000,
        ),
        context,
      );
    }

    expect(delta.error, isNull);
    expect(delta.result, 200 * 4096);
  });

  test('an unserializable emitted value fails only its handler', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession();
    final context = LuaExecutionContext<String>(
      dispatcher: ParallelDispatcher(),
    );
    final bundle = LuaProgramBundle(
      revision: 'sha256:unserializable',
      entrypoint: 'main',
      modules: const {
        'main': '''
return {
  bad = function() notify(function() end) end,
  good = function() return "still alive" end,
}
''',
      },
    );
    final failed = await session.invoke(
      LuaInvokeRequest(
        bundle: bundle,
        handler: 'bad',
        yieldTime: const Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );

    expect(failed.error, isA<LuaScriptException>());
    expect(failed.error!.message, contains('not JSON serializable'));

    // A privileged-layer failure must not destroy the reusable native worker.
    final recovered = await session.invoke(
      LuaInvokeRequest(
        bundle: bundle,
        handler: 'good',
        yieldTime: const Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    expect(recovered.error, isNull);
    expect(recovered.result, 'still alive');
  });

  test('memory exhausted while encoding a result stays classified', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession(
      limits: const LuaRuntimeLimits(maxMemoryBytes: 1024 * 1024),
    );
    // The handler allocates well inside the cap; encoding the same value into
    // a protocol frame needs several copies of it and cannot fit.
    final delta = await session.invoke(
      LuaInvokeRequest(
        bundle: LuaProgramBundle(
          revision: 'sha256:oversized-result',
          entrypoint: 'main',
          modules: const {
            'main':
                'return {run = function() return string.rep("y", 400000) end}',
          },
        ),
        handler: 'run',
        yieldTime: const Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: ParallelDispatcher()),
      workingDirectory: Directory.current.path,
    );

    expect(delta.error, isNotNull);
    expect(delta.error, isNot(isA<LuaHostException>()));
    expect(delta.error!.message.toLowerCase(), contains('memory'));
  });

  test('yielded infinite work is killed by consumer cancellation', () async {
    final runtime = _runtime(command);
    addTearDown(runtime.close);
    final session = runtime.createSession();
    final cancellation = ManualCancellation();
    final context = LuaExecutionContext<String>(
      dispatcher: ParallelDispatcher(),
      cancellation: cancellation,
    );
    final delta = await session.execute(
      const LuaExecuteRequest(
        source: 'yield_control(); while true do end',
        yieldTime: Duration(seconds: 5),
        maxOutputTokens: 1000,
      ),
      context,
      workingDirectory: Directory.current.path,
    );
    expect(delta.running, isTrue);
    cancellation.cancel();
    await pumpEventQueue();

    var cancelled = await session.wait(
      LuaWaitRequest(
        cellId: delta.cellId,
        yieldTime: const Duration(milliseconds: 10),
        maxOutputTokens: 1000,
      ),
      context,
    );
    expect(cancelled.running, isFalse);
    for (
      var attempt = 0;
      attempt < 50 && cancelled.error is! LuaCellNotFoundException;
      attempt += 1
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cancelled = await session.wait(
        LuaWaitRequest(
          cellId: delta.cellId,
          yieldTime: const Duration(milliseconds: 10),
          maxOutputTokens: 1000,
        ),
        context,
      );
    }
    expect(cancelled.error, isA<LuaCellNotFoundException>());
  });
}

LuaToolRuntime<String> _runtime(LuaHostCommand command) => LuaToolRuntime(
  host: command,
  processLauncher: const IoLuaHostProcessLauncher(),
  clock: const SystemLuaClock(),
  ids: SequenceIds(),
);

final class ParallelDispatcher implements LuaToolDispatcher<String> {
  int active = 0;
  int maximumActive = 0;

  @override
  Future<LuaToolResult<String>> invoke(LuaToolInvocation invocation) async {
    active += 1;
    if (active > maximumActive) maximumActive = active;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    active -= 1;
    return LuaToolResult(value: invocation.arguments['value']! as String);
  }
}

final class SequenceIds implements LuaIdGenerator {
  int value = 0;

  @override
  String generate() => '${++value}';
}

final class ManualCancellation implements LuaCancellationSignal {
  final List<void Function()> callbacks = [];

  @override
  void onCancel(void Function() callback) => callbacks.add(callback);

  void cancel() {
    for (final callback in callbacks) {
      callback();
    }
  }
}

final class ContractCallbacks implements LuaHostCallbackDispatcher<String> {
  int calls = 0;
  int streams = 0;

  @override
  Future<LuaHostResult<String>> call(LuaHostInvocation invocation) async {
    calls += 1;
    return const LuaHostResult(value: {'model': 'test'});
  }

  @override
  Stream<LuaHostResult<String>> open(LuaHostInvocation invocation) {
    streams += 1;
    return Stream.value(
      const LuaHostResult(value: {'type': 'text_delta', 'text': 'hello'}),
    );
  }
}

final class EchoCallbacks implements LuaHostCallbackDispatcher<String> {
  EchoCallbacks(int payloadBytes) : payload = 'x' * payloadBytes;

  final String payload;

  @override
  Future<LuaHostResult<String>> call(LuaHostInvocation invocation) async =>
      LuaHostResult(value: payload);

  @override
  Stream<LuaHostResult<String>> open(LuaHostInvocation invocation) =>
      const Stream.empty();
}

final class HangingCallbacks implements LuaHostCallbackDispatcher<String> {
  bool cancelled = false;

  @override
  Future<LuaHostResult<String>> call(LuaHostInvocation invocation) {
    invocation.cancellation.onCancel(() => throw StateError('cleanup failed'));
    invocation.cancellation.onCancel(() => cancelled = true);
    return Completer<LuaHostResult<String>>().future;
  }

  @override
  Stream<LuaHostResult<String>> open(LuaHostInvocation invocation) =>
      const Stream.empty();
}
