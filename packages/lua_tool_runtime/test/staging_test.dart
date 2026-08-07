import 'dart:io';

import 'package:lua_tool_runtime/lua_tool_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('stages the host and immutable runtime files offline', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-package-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-output-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final native = Directory(p.join(root.path, 'native'))..createSync();
    File(p.join(native.path, 'bootstrap.lua')).writeAsStringSync('bootstrap');
    File(p.join(native.path, 'LICENSE.txt')).writeAsStringSync('license');
    File(p.join(native.path, 'VERSION')).writeAsStringSync('5.5.1');
    final runner = FakeBuildRunner();

    final distribution = await stageLuaToolRuntime(
      destination: destination.path,
      packageRoot: root.path,
      buildDirectory: p.join(root.path, 'build'),
      runner: runner,
    );

    expect(runner.commands, hasLength(2));
    expect(runner.commands.first, containsAllInOrder(['cmake', '-S']));
    expect(File(distribution.hostPath).readAsStringSync(), 'host');
    expect(File(distribution.bootstrapPath).readAsStringSync(), 'bootstrap');
    expect(
      File(
        p.join(destination.path, 'lua_tool_runtime', 'LICENSE.txt'),
      ).readAsStringSync(),
      'license',
    );
  });

  test('rejects a failed native build and invalid CLI modes', () async {
    final runner = FakeBuildRunner(failAt: 1);
    await expectLater(
      stageLuaToolRuntime(
        destination: 'unused',
        packageRoot: 'package',
        buildDirectory: 'build',
        runner: runner,
      ),
      throwsA(isA<LuaHostBuildException>()),
    );
    expect(
      const LuaHostBuildException('failed').toString(),
      'LuaHostBuildException: failed',
    );
    await expectLater(
      stageLuaToolRuntime(
        destination: 'unused',
        packageRoot: 'package',
        buildDirectory: 'build',
        runner: FakeBuildRunner(failAt: 2),
      ),
      throwsA(isA<LuaHostBuildException>()),
    );
    await expectLater(
      stageLuaToolRuntime(
        destination: 'unused',
        packageRoot: 'package',
        buildDirectory: 'build',
        runner: FakeBuildRunner(createHost: false),
      ),
      throwsA(isA<LuaHostBuildException>()),
    );
    expect(() => LuaBuildMode.parse('profile'), throwsFormatException);
  });

  test('resolves a staged command without product-specific paths', () {
    final command = LuaHostCommand.fromDirectory('/bundle');
    expect(command.executable, contains('lua-tool-runtime-host'));
    expect(command.arguments.single, contains('bootstrap.lua'));
  });

  test('isolates the default CMake cache by package source identity', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-sources-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-destination-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final firstRoot = _fakePackageRoot(root, 'dart-packages-first');
    final secondRoot = _fakePackageRoot(root, 'dart-packages-second');
    final firstRunner = FakeBuildRunner();
    final secondRunner = FakeBuildRunner();
    final previousCurrent = Directory.current;
    Directory.current = root;
    try {
      await stageLuaToolRuntime(
        destination: p.join(destination.path, 'first'),
        packageRoot: firstRoot,
        runner: firstRunner,
      );
      await stageLuaToolRuntime(
        destination: p.join(destination.path, 'second'),
        packageRoot: secondRoot,
        runner: secondRunner,
      );
    } finally {
      Directory.current = previousCurrent;
    }

    final firstBuild = firstRunner.commands.first[4];
    final secondBuild = secondRunner.commands.first[4];
    expect(firstBuild, isNot(secondBuild));
    expect(firstBuild, contains('dart-packages-first'));
    expect(secondBuild, contains('dart-packages-second'));
  });
}

String _fakePackageRoot(Directory parent, String checkout) {
  final root = Directory(
    p.join(parent.path, checkout, 'packages', 'lua_tool_runtime'),
  )..createSync(recursive: true);
  final native = Directory(p.join(root.path, 'native'))..createSync();
  File(p.join(native.path, 'bootstrap.lua')).writeAsStringSync('bootstrap');
  return root.path;
}

final class FakeBuildRunner implements LuaBuildCommandRunner {
  FakeBuildRunner({this.failAt, this.createHost = true});

  final int? failAt;
  final bool createHost;
  final List<List<String>> commands = [];

  @override
  Future<int> run(String executable, List<String> arguments) async {
    commands.add([executable, ...arguments]);
    if (commands.length == failAt) return 1;
    if (commands.length == 2 && createHost) {
      final buildDirectory = arguments[1];
      final host = File(
        p.join(
          buildDirectory,
          'host',
          Platform.isWindows
              ? 'lua-tool-runtime-host.exe'
              : 'lua-tool-runtime-host',
        ),
      );
      host.parent.createSync(recursive: true);
      host.writeAsStringSync('host');
    }
    return 0;
  }
}
