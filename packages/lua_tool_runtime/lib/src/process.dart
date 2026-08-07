import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Executable and fixed arguments for the native host.
final class LuaHostCommand {
  /// Creates a host command.
  const LuaHostCommand({
    required this.executable,
    this.arguments = const [],
    this.environment = const {},
  });

  /// Host executable path.
  final String executable;

  /// Arguments placed before protocol input.
  final List<String> arguments;

  /// Additional environment variables for the helper.
  final Map<String, String> environment;

  /// Returns a copy with [values] merged into the environment.
  LuaHostCommand withEnvironment(Map<String, String> values) => LuaHostCommand(
    executable: executable,
    arguments: arguments,
    environment: {...environment, ...values},
  );

  /// Resolves a host staged by `lua_tool_runtime:stage`.
  factory LuaHostCommand.fromDirectory(String directory) {
    final separator = Platform.pathSeparator;
    final executableName = Platform.isWindows
        ? 'lua-tool-runtime-host.exe'
        : 'lua-tool-runtime-host';
    return LuaHostCommand(
      executable: '$directory$separator$executableName',
      arguments: [
        '$directory${separator}lua_tool_runtime${separator}bootstrap.lua',
      ],
    );
  }
}

/// Minimal bidirectional process used by the protocol runtime.
abstract interface class LuaHostProcess {
  /// UTF-8 stdout chunks.
  Stream<String> get outputs;

  /// Native exit code.
  Future<int> get exitCode;

  /// Writes protocol input.
  Future<void> write(String value);

  /// Terminates the process.
  Future<void> terminate();
}

/// Creates host processes.
abstract interface class LuaHostProcessLauncher {
  /// Starts [command] in [workingDirectory].
  Future<LuaHostProcess> start(
    LuaHostCommand command, {
    required String workingDirectory,
  });
}

/// `dart:io` host process launcher.
final class IoLuaHostProcessLauncher implements LuaHostProcessLauncher {
  /// Creates an IO launcher.
  const IoLuaHostProcessLauncher();

  @override
  Future<LuaHostProcess> start(
    LuaHostCommand command, {
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      command.executable,
      command.arguments,
      workingDirectory: workingDirectory,
      environment: command.environment,
    );
    return _IoLuaHostProcess(process);
  }
}

final class _IoLuaHostProcess implements LuaHostProcess {
  _IoLuaHostProcess(this._process) {
    _stderr = _process.stderr.transform(utf8.decoder).listen((chunk) {
      _stderrTail = '$_stderrTail$chunk';
      if (_stderrTail.length > 8192) {
        _stderrTail = _stderrTail.substring(_stderrTail.length - 8192);
      }
    });
  }

  final Process _process;
  late final StreamSubscription<String> _stderr;
  String _stderrTail = '';

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Stream<String> get outputs => _process.stdout.transform(utf8.decoder);

  @override
  Future<void> write(String value) async {
    _process.stdin.write(value);
    await _process.stdin.flush();
  }

  @override
  Future<void> terminate() async {
    await _process.stdin.close();
    if (_process.kill()) {
      await _process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (!Platform.isWindows) _process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    await _stderr.cancel();
  }
}

/// UTC clock used for deterministic expiry tests.
abstract interface class LuaClock {
  /// Returns current UTC time.
  DateTime nowUtc();
}

/// System clock implementation.
final class SystemLuaClock implements LuaClock {
  /// Creates a system clock.
  const SystemLuaClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Generates cell identifiers.
abstract interface class LuaIdGenerator {
  /// Returns a new session-local identifier.
  String generate();
}
