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
