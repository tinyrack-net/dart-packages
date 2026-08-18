import 'dart:convert';
import 'dart:io';

import 'package:lua_tool_runtime/lua_tool_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('IO launcher streams UTF-8, writes input, and drains stderr', () async {
    final directory = await Directory.systemTemp.createTemp('lua-process-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/child.dart')
      ..writeAsStringSync('''
import 'dart:io';
void main() {
  stderr.write(List.filled(9000, 'e').join());
  stdout.write(stdin.readLineSync());
  stdout.write(Platform.environment['LUA_TEST_VALUE']);
  stdout.write(':');
  stdout.write(Platform.environment.containsKey('PATH'));
}
''');
    final process = await const IoLuaHostProcessLauncher().start(
      LuaHostCommand(
        executable: Platform.resolvedExecutable,
        arguments: [script.path],
        environment: const {'LUA_TEST_VALUE': 'environment'},
      ),
      workingDirectory: directory.path,
    );
    final output = process.outputs.transform(const LineSplitter()).toList();
    await process.write('input\n');
    expect(await process.exitCode, 0);
    expect((await output).join(), 'inputenvironment:false');
    await process.terminate();
  });

  test('terminate during an in-flight write kills the host', () async {
    final directory = await Directory.systemTemp.createTemp('lua-process-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/child.dart')
      ..writeAsStringSync('''
Future<void> main() async {
  // Never reads stdin, so a large write keeps its flush pending.
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await const IoLuaHostProcessLauncher().start(
      LuaHostCommand(
        executable: Platform.resolvedExecutable,
        arguments: [script.path],
      ),
      workingDirectory: directory.path,
    );
    final pending = process
        .write('x' * (8 << 20))
        .then<Object?>((_) => null, onError: (Object error) => error);
    await process.terminate();
    expect(await process.exitCode, isNotNull);
    await pending;
  });

  test('writes queued behind an accepted write stay ordered', () async {
    final directory = await Directory.systemTemp.createTemp('lua-process-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/child.dart')
      ..writeAsStringSync('''
import 'dart:io';
void main() {
  stdout.write(stdin.readLineSync());
  stdout.write(stdin.readLineSync());
}
''');
    final process = await const IoLuaHostProcessLauncher().start(
      LuaHostCommand(
        executable: Platform.resolvedExecutable,
        arguments: [script.path],
      ),
      workingDirectory: directory.path,
    );
    final output = process.outputs.transform(const LineSplitter()).toList();
    final first = process.write('one\n');
    final second = process.write('two\n');
    await Future.wait([first, second]);
    expect(await process.exitCode, 0);
    expect((await output).join(), 'onetwo');
    await process.terminate();
  });

  test('a write after terminate is rejected without touching stdin', () async {
    final directory = await Directory.systemTemp.createTemp('lua-process-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/child.dart')
      ..writeAsStringSync('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await const IoLuaHostProcessLauncher().start(
      LuaHostCommand(
        executable: Platform.resolvedExecutable,
        arguments: [script.path],
      ),
      workingDirectory: directory.path,
    );
    final termination = process.terminate();
    expect(process.write('late\n'), throwsStateError);
    expect(identical(process.terminate(), termination), isTrue);
    await termination;
    expect(await process.exitCode, isNotNull);
  });

  test('IO launcher terminates a live child', () async {
    final directory = await Directory.systemTemp.createTemp('lua-process-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/child.dart')
      ..writeAsStringSync('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await const IoLuaHostProcessLauncher().start(
      LuaHostCommand(
        executable: Platform.resolvedExecutable,
        arguments: [script.path],
      ),
      workingDirectory: directory.path,
    );
    await process.terminate();
    expect(await process.exitCode, isNotNull);
  });
}
