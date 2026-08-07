@Tags(['host'])
library;

import 'dart:async';
import 'dart:io';

import 'package:lua_tool_runtime/lua_tool_runtime.dart';
import 'package:test/test.dart';

void main() {
  late Directory distributionDirectory;
  late LuaHostCommand command;

  setUpAll(() async {
    distributionDirectory = await Directory.systemTemp.createTemp(
      'lua-tool-runtime-contract-',
    );
    final distribution = await stageLuaToolRuntime(
      destination: distributionDirectory.path,
      buildMode: LuaBuildMode.debug,
    );
    command = LuaHostCommand(
      executable: distribution.hostPath,
      arguments: [distribution.bootstrapPath],
    );
  });

  tearDownAll(() => distributionDirectory.delete(recursive: true));

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
text(values[1][1].output .. values[2][1].output)
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
    return LuaToolResult(output: invocation.arguments['value']! as String);
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
