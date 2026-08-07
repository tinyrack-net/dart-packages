import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Native optimization mode.
enum LuaBuildMode {
  /// Debug symbols and assertions.
  debug,

  /// Optimized distribution build.
  release;

  /// Parses a command-line mode.
  static LuaBuildMode parse(String value) => switch (value) {
    'debug' => debug,
    'release' => release,
    _ => throw FormatException('Unsupported Lua build mode: $value'),
  };

  String get _cmakeName => switch (this) {
    debug => 'Debug',
    release => 'Release',
  };
}

/// Files staged for a consumer bundle.
final class LuaHostDistribution {
  /// Creates a distribution description.
  const LuaHostDistribution({
    required this.hostPath,
    required this.bootstrapPath,
  });

  /// Native helper path.
  final String hostPath;

  /// Privileged bootstrap path.
  final String bootstrapPath;
}

/// Runs native build commands; replaceable by deterministic tests.
abstract interface class LuaBuildCommandRunner {
  /// Runs one command and returns its exit code.
  Future<int> run(String executable, List<String> arguments);
}

/// Native command failure during staging.
final class LuaHostBuildException implements Exception {
  /// Creates a build error.
  const LuaHostBuildException(this.message);

  /// Human-readable failure.
  final String message;

  @override
  String toString() => 'LuaHostBuildException: $message';
}

/// Builds and stages the native host without downloading dependencies.
Future<LuaHostDistribution> stageLuaToolRuntime({
  required String destination,
  LuaBuildMode buildMode = LuaBuildMode.release,
  String? packageRoot,
  String? buildDirectory,
  LuaBuildCommandRunner runner = const IoLuaBuildCommandRunner(),
}) async {
  final root = packageRoot ?? await resolveLuaToolRuntimePackageRoot();
  final build =
      buildDirectory ??
      p.join(
        Directory.current.absolute.path,
        '.dart_tool',
        'lua_tool_runtime',
        _packageSourceIdentity(root),
        '${Platform.operatingSystem}-${buildMode.name}',
      );
  final configure = await runner.run('cmake', [
    '-S',
    p.join(root, 'native'),
    '-B',
    build,
    '-DCMAKE_BUILD_TYPE=${buildMode._cmakeName}',
  ]);
  if (configure != 0) {
    throw LuaHostBuildException('CMake configure exited with $configure.');
  }
  final compile = await runner.run('cmake', [
    '--build',
    build,
    '--config',
    buildMode._cmakeName,
  ]);
  if (compile != 0) {
    throw LuaHostBuildException('CMake build exited with $compile.');
  }

  final executableName = Platform.isWindows
      ? 'lua-tool-runtime-host.exe'
      : 'lua-tool-runtime-host';
  final builtHost = File(p.join(build, 'host', executableName));
  if (!builtHost.existsSync()) {
    throw LuaHostBuildException(
      'Native build did not produce ${builtHost.path}.',
    );
  }
  final output = Directory(p.normalize(p.absolute(destination)))
    ..createSync(recursive: true);
  final stagedHost = await builtHost.copy(p.join(output.path, executableName));
  final data = Directory(p.join(output.path, 'lua_tool_runtime'))
    ..createSync(recursive: true);
  for (final name in ['bootstrap.lua', 'LICENSE.txt', 'VERSION', 'SHA256']) {
    final source = File(p.join(root, 'native', name));
    if (source.existsSync()) await source.copy(p.join(data.path, name));
  }
  return LuaHostDistribution(
    hostPath: stagedHost.path,
    bootstrapPath: p.join(data.path, 'bootstrap.lua'),
  );
}

String _packageSourceIdentity(String packageRoot) {
  final checkout = p.basename(
    p.dirname(p.dirname(p.normalize(p.absolute(packageRoot)))),
  );
  final safe = checkout.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  return safe.isEmpty ? 'lua_tool_runtime' : safe;
}

/// Resolves this package independently of pub-cache or workspace layout.
Future<String> resolveLuaToolRuntimePackageRoot() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:lua_tool_runtime/lua_tool_runtime.dart'),
  );
  if (library == null || library.scheme != 'file') {
    throw const LuaHostBuildException(
      'Could not resolve the lua_tool_runtime package root.',
    );
  }
  return File.fromUri(library).parent.parent.path;
}

/// Real command runner.
final class IoLuaBuildCommandRunner implements LuaBuildCommandRunner {
  /// Creates an IO command runner.
  const IoLuaBuildCommandRunner();

  @override
  Future<int> run(String executable, List<String> arguments) async {
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}
