import 'dart:io';

import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

/// Executor whose behavior is fully scripted for deterministic edge coverage.
final class _ScriptedExecutor implements ProcessExecutor {
  _ScriptedExecutor({
    this.runResult,
    this.runThrows = false,
    this.inheritedExit,
    this.inheritedThrows = false,
  });

  final ProcessResult? runResult;
  final bool runThrows;
  final int? inheritedExit;
  final bool inheritedThrows;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (runThrows) {
      throw const ProcessException('missing', [], 'boom');
    }
    return runResult ?? ProcessResult(0, 0, '', '');
  }

  @override
  Future<int> runInherited(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (inheritedThrows) {
      throw const ProcessException('missing', [], 'boom');
    }
    return inheritedExit ?? 0;
  }
}

void main() {
  group('default IoProcessExecutor', () {
    test('run captures output from a real process', () async {
      final result = await defaultProcessExecutor.run(
        Platform.resolvedExecutable,
        const ['--version'],
      );

      expect(result.exitCode, 0);
    });

    test('runInherited returns the real exit code', () async {
      final code = await const IoProcessExecutor().runInherited(
        Platform.resolvedExecutable,
        const ['--version'],
      );

      expect(code, 0);
    });
  });

  group('runCapture', () {
    test('wraps ProcessException from a missing executable', () async {
      await expectLater(
        runCapture(
          'shipworld-nonexistent-binary-xyz',
          const [],
          executor: _ScriptedExecutor(runThrows: true),
        ),
        throwsA(isA<ShipworldException>()),
      );
    });
  });

  group('runChecked', () {
    test('throws on a non-zero exit code', () async {
      await expectLater(
        runChecked(
          'tool',
          const ['--fail'],
          executor: _ScriptedExecutor(
            runResult: ProcessResult(0, 3, 'out', 'err'),
          ),
        ),
        throwsA(
          isA<ShipworldException>().having(
            (error) => error.message,
            'message',
            allOf(contains('exit code 3'), contains('out'), contains('err')),
          ),
        ),
      );
    });
  });

  group('runInherited (top-level)', () {
    test('wraps ProcessException from the executor', () async {
      await expectLater(
        runInherited(
          'tool',
          const [],
          executor: _ScriptedExecutor(inheritedThrows: true),
        ),
        throwsA(isA<ShipworldException>()),
      );
    });

    test('throws on a non-zero exit code', () async {
      await expectLater(
        runInherited(
          'tool',
          const [],
          executor: _ScriptedExecutor(inheritedExit: 5),
        ),
        throwsA(
          isA<ShipworldException>().having(
            (error) => error.message,
            'message',
            contains('exit code 5'),
          ),
        ),
      );
    });

    test('completes normally on a zero exit code', () async {
      await runInherited(
        'tool',
        const [],
        executor: _ScriptedExecutor(inheritedExit: 0),
      );
    });
  });
}
