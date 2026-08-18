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
      File(p.join(destination.path, 'lua_tool_runtime', 'LICENSE.txt'))
          .readAsStringSync(),
      'license',
    );
  });

  test(
    'uses the supplied CMake executable for every native build step',
    () async {
      final root = await Directory.systemTemp.createTemp('lua-stage-cmake-');
      final destination = await Directory.systemTemp.createTemp(
        'lua-stage-cmake-output-',
      );
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => destination.delete(recursive: true));
      final native = Directory(p.join(root.path, 'native'))..createSync();
      File(p.join(native.path, 'bootstrap.lua')).writeAsStringSync('bootstrap');
      final runner = FakeBuildRunner();
      final cmakeExecutable = p.join(
        'C:',
        'Program Files',
        'CMake',
        'cmake.exe',
      );

      await stageLuaToolRuntime(
        destination: destination.path,
        packageRoot: root.path,
        buildDirectory: p.join(root.path, 'build'),
        cmakeExecutable: cmakeExecutable,
        runner: runner,
      );

      expect(runner.commands, hasLength(2));
      expect(
        runner.commands.map((command) => command.first),
        everyElement(cmakeExecutable),
      );
    },
  );

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

  test('discards a cache generated from a different package source', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-stale-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-stale-output-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final packageRoot = _fakePackageRoot(root, 'dart-packages-new');
    final build = Directory(p.join(root.path, 'build'))
      ..createSync(recursive: true);
    _writeCache(
      build,
      home: p.join(root.path, 'dart-packages-old', 'native'),
      cacheFileDirectory: build.path,
    );
    final stale = File(p.join(build.path, 'stale.vcxproj'))
      ..writeAsStringSync('stale');

    await stageLuaToolRuntime(
      destination: destination.path,
      packageRoot: packageRoot,
      buildDirectory: build.path,
      runner: FakeBuildRunner(),
    );

    expect(stale.existsSync(), isFalse);
    expect(File(p.join(build.path, 'CMakeCache.txt')).existsSync(), isFalse);
  });

  test('discards a cache generated for a different build directory', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-moved-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-moved-output-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final packageRoot = _fakePackageRoot(root, 'dart-packages-moved');
    final build = Directory(p.join(root.path, 'build'))
      ..createSync(recursive: true);
    _writeCache(
      build,
      home: p.join(packageRoot, 'native'),
      cacheFileDirectory: p.join(root.path, 'elsewhere'),
    );
    final stale = File(p.join(build.path, 'stale.vcxproj'))
      ..writeAsStringSync('stale');

    await stageLuaToolRuntime(
      destination: destination.path,
      packageRoot: packageRoot,
      buildDirectory: build.path,
      runner: FakeBuildRunner(),
    );

    expect(stale.existsSync(), isFalse);
  });

  test('keeps a cache that still matches the current build', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-warm-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-warm-output-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final packageRoot = _fakePackageRoot(root, 'dart-packages-warm');
    final build = Directory(p.join(root.path, 'build'))
      ..createSync(recursive: true);
    _writeCache(
      build,
      home: p.join(packageRoot, 'native'),
      cacheFileDirectory: build.path,
    );
    final warm = File(p.join(build.path, 'warm.o'))..writeAsStringSync('warm');

    await stageLuaToolRuntime(
      destination: destination.path,
      packageRoot: packageRoot,
      buildDirectory: build.path,
      runner: FakeBuildRunner(),
    );

    expect(warm.existsSync(), isTrue);
  });

  test('keeps a cache recorded with Windows casing and separators', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-casing-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-casing-output-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final packageRoot = _fakePackageRoot(root, 'dart-packages-casing');
    final build = Directory(p.join(root.path, 'build'))
      ..createSync(recursive: true);
    _writeCache(
      build,
      home: p.join(packageRoot, 'native').toUpperCase(),
      cacheFileDirectory: build.path.replaceAll(r'\', '/'),
    );
    final warm = File(p.join(build.path, 'warm.obj'))
      ..writeAsStringSync('warm');

    await stageLuaToolRuntime(
      destination: destination.path,
      packageRoot: packageRoot,
      buildDirectory: build.path,
      runner: FakeBuildRunner(),
    );

    expect(warm.existsSync(), isTrue);
  }, testOn: 'windows');

  test('configures a build directory with no previous cache', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-cold-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-cold-output-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final packageRoot = _fakePackageRoot(root, 'dart-packages-cold');
    final build = Directory(p.join(root.path, 'build'))
      ..createSync(recursive: true);
    final unrelated = File(p.join(build.path, 'notes.txt'))
      ..writeAsStringSync('notes');

    await stageLuaToolRuntime(
      destination: destination.path,
      packageRoot: packageRoot,
      buildDirectory: build.path,
      runner: FakeBuildRunner(),
    );

    expect(unrelated.existsSync(), isTrue);
  });

  test('rebuilds after a cache file that cannot be parsed', () async {
    final root = await Directory.systemTemp.createTemp('lua-stage-garbled-');
    final destination = await Directory.systemTemp.createTemp(
      'lua-stage-garbled-output-',
    );
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => destination.delete(recursive: true));
    final packageRoot = _fakePackageRoot(root, 'dart-packages-garbled');
    final build = Directory(p.join(root.path, 'build'))
      ..createSync(recursive: true);
    File(p.join(build.path, 'CMakeCache.txt'))
        .writeAsStringSync('# no useful entries\n');
    final stale = File(p.join(build.path, 'stale.vcxproj'))
      ..writeAsStringSync('stale');

    await stageLuaToolRuntime(
      destination: destination.path,
      packageRoot: packageRoot,
      buildDirectory: build.path,
      runner: FakeBuildRunner(),
    );

    expect(stale.existsSync(), isFalse);
  });
}

void _writeCache(
  Directory build, {
  required String home,
  required String cacheFileDirectory,
}) {
  File(p.join(build.path, 'CMakeCache.txt')).writeAsStringSync(
    '# This is the CMakeCache file.\n'
    'CMAKE_CACHEFILE_DIR:INTERNAL=$cacheFileDirectory\n'
    'CMAKE_HOME_DIRECTORY:INTERNAL=$home\n',
  );
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
