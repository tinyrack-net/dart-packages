import 'dart:async';
import 'dart:convert';

import 'package:lua_tool_runtime/lua_tool_runtime.dart';
import 'package:test/test.dart';

void main() {
  late FakeProcessLauncher launcher;
  late FakeClock clock;
  late LuaToolRuntime<String> runtime;
  late LuaRuntimeSession<String> session;

  setUp(() {
    launcher = FakeProcessLauncher();
    clock = FakeClock();
    runtime = LuaToolRuntime<String>(
      host: const LuaHostCommand(
        executable: 'lua-tool-runtime-host',
        arguments: ['bootstrap.lua'],
      ),
      processLauncher: launcher,
      clock: clock,
      ids: SequenceIds(),
    );
    session = runtime.createSession();
  });

  tearDown(() => runtime.close());

  test('dispatches a tool batch and preserves opaque resources', () async {
    final dispatcher = RecordingDispatcher();
    final pending = session.execute(
      const LuaExecuteRequest(
        source: 'text(tools.echo({value="hello"}).output)',
        tools: [LuaToolDefinition(name: 'echo', description: 'Echo')],
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: dispatcher),
    );
    await pumpEventQueue();
    final cellId = launcher.process.writtenFrame(0)['cell_id']! as String;

    launcher.process.emitFrame(cellId, 1, 'tool_batch', {
      'calls': [
        {
          'request_id': '1:1',
          'name': 'echo',
          'arguments': {'value': 'hello'},
        },
      ],
    });
    await pumpEventQueue();

    expect(dispatcher.calls, ['echo:hello']);
    final response = launcher.process.writtenFrame(1);
    expect(response['type'], 'tool_results');
    final payload = Map<String, Object?>.from(response['payload']! as Map);
    final results = payload['results']! as List<Object?>;
    final result = Map<String, Object?>.from(results.single! as Map);
    final value = Map<String, Object?>.from(result['value']! as Map);
    final resources = value['attachments']! as List<Object?>;
    final descriptor = Map<String, Object?>.from(resources.single! as Map);
    final handle = descriptor['handle']! as String;

    launcher.process
      ..emitFrame(cellId, 2, 'output', {'kind': 'image', 'value': handle})
      ..emitFrame(cellId, 3, 'output', {'kind': 'audio', 'value': handle})
      ..emitFrame(cellId, 4, 'output', {
        'kind': 'generated_image',
        'value': handle,
      })
      ..emitFrame(cellId, 5, 'completed', {'store': <String, Object?>{}});

    var delta = await pending;
    expect(delta.resources.single.value, 'resource-value');
    expect(delta.emittedResources.single.value, 'resource-value');
    while (delta.running) {
      delta = await session.wait(
        LuaWaitRequest(
          cellId: cellId,
          yieldTime: const Duration(seconds: 1),
          maxOutputTokens: 1000,
        ),
        LuaExecutionContext(dispatcher: dispatcher),
      );
    }
    expect(delta.running, isFalse);
  });

  test('resumes yielded cells and persists JSON session state', () async {
    final context = LuaExecutionContext<String>(
      dispatcher: RecordingDispatcher(),
    );
    final pending = session.execute(
      const LuaExecuteRequest(
        source: 'yield_control()',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      context,
    );
    await pumpEventQueue();
    final cellId = launcher.process.writtenFrame(0)['cell_id']! as String;
    launcher.process.emitFrame(cellId, 1, 'yielded', {
      'store': {'answer': 42},
    });
    expect((await pending).running, isTrue);

    final resumed = session.wait(
      LuaWaitRequest(
        cellId: cellId,
        yieldTime: const Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      context,
    );
    await pumpEventQueue();
    expect(launcher.process.writtenFrame(1)['type'], 'continue');
    launcher.process.emitFrame(cellId, 2, 'completed', {
      'store': {'answer': 43},
    });
    expect((await resumed).running, isFalse);
    expect(session.store, {'answer': 43});
  });

  test(
    'terminates the least recently used cell at the session limit',
    () async {
      final limited = runtime.createSession(
        limits: const LuaRuntimeLimits(maxLiveCells: 1),
      );
      final first = limited.execute(
        const LuaExecuteRequest(
          source: 'yield_control()',
          yieldTime: Duration(milliseconds: 1),
          maxOutputTokens: 1000,
        ),
        LuaExecutionContext(dispatcher: RecordingDispatcher()),
      );
      await pumpEventQueue();
      final firstId =
          launcher.processes.first.writtenFrame(0)['cell_id']! as String;
      launcher.processes.first.emitFrame(firstId, 1, 'yielded', {
        'store': <String, Object?>{},
      });
      await first;

      unawaited(
        limited.execute(
          const LuaExecuteRequest(
            source: 'yield_control()',
            yieldTime: Duration(milliseconds: 1),
            maxOutputTokens: 1000,
          ),
          LuaExecutionContext(dispatcher: RecordingDispatcher()),
        ),
      );
      await pumpEventQueue();
      expect(launcher.processes.first.terminated, isTrue);
    },
  );

  test('rejects malformed and oversized protocol frames', () async {
    final pending = session.execute(
      const LuaExecuteRequest(
        source: 'text("hello")',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );
    await pumpEventQueue();
    launcher.process.emit('{broken}\n');
    final delta = await pending;
    expect(delta.error, isA<LuaProtocolException>());
    expect(launcher.process.terminated, isTrue);

    final tiny = runtime.createSession(
      limits: const LuaRuntimeLimits(maxFrameBytes: 10),
    );
    await expectLater(
      tiny.execute(
        const LuaExecuteRequest(
          source: 'x',
          yieldTime: Duration.zero,
          maxOutputTokens: 1,
        ),
        LuaExecutionContext(dispatcher: RecordingDispatcher()),
      ),
      throwsA(isA<LuaLimitException>()),
    );
  });

  test('rejects foreign resources and classifies script errors', () async {
    final pending = session.execute(
      const LuaExecuteRequest(
        source: 'image("foreign")',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );
    await pumpEventQueue();
    final cellId = launcher.process.writtenFrame(0)['cell_id']! as String;
    launcher.process.emitFrame(cellId, 1, 'output', {
      'kind': 'image',
      'value': 'foreign',
    });
    final invalid = await pending;
    expect(invalid.error, isA<LuaProtocolException>());

    final second = session.execute(
      const LuaExecuteRequest(
        source: 'error("bad")',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );
    await pumpEventQueue();
    final secondProcess = launcher.processes.last;
    final secondId = secondProcess.writtenFrame(0)['cell_id']! as String;
    secondProcess.emitFrame(secondId, 1, 'error', {
      'message': 'bad stack',
      'store': <String, Object?>{},
    });
    expect((await second).error, isA<LuaScriptException>());
  });

  test('enforces source limits and supports explicit termination', () async {
    final limited = runtime.createSession(
      limits: const LuaRuntimeLimits(maxSourceBytes: 1),
    );
    final rejected = await limited.execute(
      const LuaExecuteRequest(
        source: 'too long',
        yieldTime: Duration.zero,
        maxOutputTokens: 1,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );
    expect(rejected.error, isA<LuaLimitException>());
    expect(rejected.error.toString(), contains('LuaLimitException'));

    final pending = session.execute(
      const LuaExecuteRequest(
        source: 'yield_control()',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );
    await pumpEventQueue();
    final cellId = launcher.process.writtenFrame(0)['cell_id']! as String;
    launcher.process.emitFrame(cellId, 1, 'yielded', {
      'store': <String, Object?>{},
    });
    await pending;
    final terminated = await session.wait(
      LuaWaitRequest(
        cellId: cellId,
        yieldTime: Duration.zero,
        maxOutputTokens: 1000,
        terminate: true,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );
    expect(terminated.terminated, isTrue);
    expect(launcher.process.terminated, isTrue);
  });

  test('sweeps idle cells and rejects use after close', () async {
    final expiring = runtime.createSession(
      limits: const LuaRuntimeLimits(idleTimeout: Duration(milliseconds: 1)),
    );
    final pending = expiring.execute(
      const LuaExecuteRequest(
        source: 'yield_control()',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );
    await pumpEventQueue();
    final cellId = launcher.process.writtenFrame(0)['cell_id']! as String;
    launcher.process.emitFrame(cellId, 1, 'yielded', {
      'store': <String, Object?>{},
    });
    await pending;
    clock.value = clock.value.add(const Duration(seconds: 1));
    runtime.sweep();
    await pumpEventQueue();
    expect(launcher.process.terminated, isTrue);

    await expiring.close();
    await expiring.close();
    expect(
      () => expiring.execute(
        const LuaExecuteRequest(
          source: 'text("x")',
          yieldTime: Duration.zero,
          maxOutputTokens: 1,
        ),
        LuaExecutionContext(dispatcher: RecordingDispatcher()),
      ),
      throwsStateError,
    );
    expect(
      () => expiring.wait(
        const LuaWaitRequest(
          cellId: 'missing',
          yieldTime: Duration.zero,
          maxOutputTokens: 1,
        ),
        LuaExecutionContext(dispatcher: RecordingDispatcher()),
      ),
      throwsStateError,
    );
  });

  test('classifies host exits, stream failures, and invalid frames', () async {
    Future<LuaCellDelta<String>> start() => session.execute(
      const LuaExecuteRequest(
        source: 'text("x")',
        yieldTime: Duration(seconds: 1),
        maxOutputTokens: 1000,
      ),
      LuaExecutionContext(dispatcher: RecordingDispatcher()),
    );

    var pending = start();
    await pumpEventQueue();
    launcher.process.exitWith(9);
    expect((await pending).error, isA<LuaHostException>());

    pending = start();
    await pumpEventQueue();
    launcher.process.failOutput(StateError('stream failed'));
    expect((await pending).error, isA<LuaHostException>());

    pending = start();
    await pumpEventQueue();
    launcher.process.crash(StateError('exit failed'));
    expect((await pending).error, isA<LuaHostException>());

    pending = start();
    await pumpEventQueue();
    launcher.process.closeOutput();
    expect((await pending).error, isA<LuaHostException>());

    pending = start();
    await pumpEventQueue();
    final process = launcher.process;
    final cellId = process.writtenFrame(0)['cell_id']! as String;
    process.emitFrame(cellId, 1, 'unknown', <String, Object?>{});
    expect((await pending).error, isA<LuaProtocolException>());

    pending = start();
    await pumpEventQueue();
    final wrong = launcher.process;
    wrong.emitFrame('foreign', 1, 'completed', {'store': <String, Object?>{}});
    expect((await pending).error, isA<LuaProtocolException>());
  });

  test(
    'handles timers, invalid calls, dispatcher errors, and output kinds',
    () async {
      final dispatcher = ThrowingDispatcher();
      final pending = session.execute(
        const LuaExecuteRequest(
          source: 'text("x")',
          yieldTime: Duration(seconds: 1),
          maxOutputTokens: 1000,
        ),
        LuaExecutionContext(dispatcher: dispatcher),
      );
      await pumpEventQueue();
      final process = launcher.process;
      final cellId = process.writtenFrame(0)['cell_id']! as String;
      process.emitFrame(cellId, 1, 'tool_batch', {
        'calls': [
          {'request_id': 'timer', 'sleep_ms': 0},
          {'request_id': 'invalid'},
          {
            'request_id': 'throws',
            'name': 'throws',
            'arguments': <String, Object?>{},
          },
        ],
      });
      await pumpEventQueue();
      final response = process.writtenFrame(1);
      final payload = Map<String, Object?>.from(response['payload']! as Map);
      expect(payload['results'], hasLength(3));
      process.emitFrame(cellId, 2, 'output', {
        'kind': 'notify',
        'value': {'ok': true},
      });
      process.emitFrame(cellId, 3, 'completed', {'store': <String, Object?>{}});
      var delta = await pending;
      final output = StringBuffer(delta.output);
      if (delta.running) {
        delta = await session.wait(
          LuaWaitRequest(
            cellId: cellId,
            yieldTime: const Duration(seconds: 1),
            maxOutputTokens: 1000,
          ),
          LuaExecutionContext(dispatcher: dispatcher),
        );
        output.write(delta.output);
      }
      expect(output.toString(), contains('{"ok":true}'));

      final invalid = startInvalidOutput(session, launcher);
      expect((await invalid).error, isA<LuaProtocolException>());

      final invalidBatch = session.execute(
        const LuaExecuteRequest(
          source: 'text("x")',
          yieldTime: Duration(seconds: 1),
          maxOutputTokens: 1000,
        ),
        LuaExecutionContext(dispatcher: dispatcher),
      );
      await pumpEventQueue();
      final invalidProcess = launcher.process;
      final invalidCell = invalidProcess.writtenFrame(0)['cell_id']! as String;
      invalidProcess.emitFrame(invalidCell, 1, 'tool_batch', {
        'calls': 'invalid',
      });
      expect((await invalidBatch).error, isA<LuaProtocolException>());
    },
  );

  test(
    'bounds incomplete frames and keeps a valid UTF-8 output tail',
    () async {
      final bounded = runtime.createSession(
        limits: const LuaRuntimeLimits(
          maxFrameBytes: 512,
          maxOutputBytes: 1024,
        ),
      );
      var pending = bounded.execute(
        const LuaExecuteRequest(
          source: 'text("x")',
          yieldTime: Duration(seconds: 1),
          maxOutputTokens: 1000,
        ),
        LuaExecutionContext(dispatcher: RecordingDispatcher()),
      );
      await pumpEventQueue();
      launcher.process.emit('x' * 513);
      expect((await pending).error, isA<LuaProtocolException>());

      final truncating = runtime.createSession(
        limits: const LuaRuntimeLimits(maxOutputBytes: 1024),
      );
      pending = truncating.execute(
        const LuaExecuteRequest(
          source: 'text("x")',
          yieldTime: Duration(seconds: 1),
          maxOutputTokens: 1000,
        ),
        LuaExecutionContext(dispatcher: RecordingDispatcher()),
      );
      await pumpEventQueue();
      final process = launcher.process;
      final cellId = process.writtenFrame(0)['cell_id']! as String;
      process.emitFrame(cellId, 1, 'output', {
        'kind': 'text',
        'value': '${'a' * 1100}🙂',
      });
      process.emitFrame(cellId, 2, 'completed', {'store': <String, Object?>{}});
      final delta = await pending;
      expect(delta.output, endsWith('🙂'));
      expect(delta.output.length, lessThan(1102));
    },
  );
}

Future<LuaCellDelta<String>> startInvalidOutput(
  LuaRuntimeSession<String> session,
  FakeProcessLauncher launcher,
) async {
  final pending = session.execute(
    const LuaExecuteRequest(
      source: 'text("x")',
      yieldTime: Duration(seconds: 1),
      maxOutputTokens: 1000,
    ),
    LuaExecutionContext(dispatcher: RecordingDispatcher()),
  );
  await pumpEventQueue();
  final process = launcher.process;
  final cellId = process.writtenFrame(0)['cell_id']! as String;
  process.emitFrame(cellId, 1, 'output', {'kind': 'video', 'value': 'x'});
  return pending;
}

final class RecordingDispatcher implements LuaToolDispatcher<String> {
  final List<String> calls = [];

  @override
  Future<LuaToolResult<String>> invoke(LuaToolInvocation invocation) async {
    calls.add('${invocation.name}:${invocation.arguments['value']}');
    return const LuaToolResult(
      output: 'hello',
      resources: [
        LuaOpaqueResource(
          value: 'resource-value',
          fileName: 'image.png',
          mimeType: 'image/png',
          byteSize: 5,
        ),
      ],
    );
  }
}

final class ThrowingDispatcher implements LuaToolDispatcher<String> {
  @override
  Future<LuaToolResult<String>> invoke(LuaToolInvocation invocation) =>
      throw StateError('tool failed');
}

final class FakeClock implements LuaClock {
  DateTime value = DateTime.utc(2026);

  @override
  DateTime nowUtc() => value;
}

final class SequenceIds implements LuaIdGenerator {
  int value = 0;

  @override
  String generate() => '${++value}';
}

final class FakeProcessLauncher implements LuaHostProcessLauncher {
  final List<FakeProcess> processes = [];

  FakeProcess get process => processes.last;

  @override
  Future<LuaHostProcess> start(
    LuaHostCommand command, {
    required String workingDirectory,
  }) async {
    expect(command.executable, 'lua-tool-runtime-host');
    final process = FakeProcess();
    processes.add(process);
    return process;
  }
}

final class FakeProcess implements LuaHostProcess {
  final StreamController<String> outputController = StreamController();
  final Completer<int> exitCodeCompleter = Completer();
  final List<String> input = [];
  bool terminated = false;

  Map<String, Object?> writtenFrame(int index) =>
      Map<String, Object?>.from(jsonDecode(input[index].trim()) as Map);

  void emit(String output) => outputController.add(output);

  void failOutput(Object error) => outputController.addError(error);

  void closeOutput() => unawaited(outputController.close());

  void exitWith(int code) => exitCodeCompleter.complete(code);

  void crash(Object error) => exitCodeCompleter.completeError(error);

  void emitFrame(
    String cellId,
    int sequence,
    String type,
    Map<String, Object?> payload,
  ) => emit(
    '${jsonEncode({'version': luaHostProtocolVersion, 'cell_id': cellId, 'sequence_id': sequence, 'type': type, 'payload': payload})}\n',
  );

  @override
  Future<int> get exitCode => exitCodeCompleter.future;

  @override
  Stream<String> get outputs => outputController.stream;

  @override
  Future<void> terminate() async {
    terminated = true;
    if (!exitCodeCompleter.isCompleted) exitCodeCompleter.complete(-1);
  }

  @override
  Future<void> write(String value) async => input.add(value);
}
