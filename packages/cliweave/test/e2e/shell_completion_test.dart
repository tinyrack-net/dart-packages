@Tags(['e2e'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const executableName = 'cliweave-fixture';
const functionPrefix = '__cliweave_fixture';

late Directory temporaryDirectory;
late String fixtureExecutable;
late String ptyDriver;

/// Lanes the CI matrix can ask for, mapped to the script the fixture prints.
///
/// `powershell` and `powershell5` share a script but run on different hosts —
/// PowerShell 7 (`pwsh`) and Windows PowerShell 5.1 (`powershell.exe`), which
/// is still the default shell on Windows and runs on .NET Framework.
const shellScripts = {
  'bash': 'bash',
  'zsh': 'zsh',
  'fish': 'fish',
  'powershell': 'powershell',
  'powershell5': 'powershell',
};

const defaultShellExecutables = {
  'bash': 'bash',
  'zsh': 'zsh',
  'fish': 'fish',
  'powershell': 'pwsh',
  'powershell5': 'powershell.exe',
};

Set<String> get requiredShells {
  return (Platform.environment['CLIWEAVE_E2E_SHELLS'] ?? '')
      .split(',')
      .map((shell) => shell.trim().toLowerCase())
      .where((shell) => shell.isNotEmpty)
      .toSet();
}

bool _selected(String shell) => requiredShells.contains(shell);

/// Resolves the binary for [shell].
///
/// `CLIWEAVE_E2E_SHELL_BASH=/bin/bash` pins a specific build, which matters on
/// macOS: the runner's PATH finds Homebrew's bash 5 first, but the bash that
/// ships with the OS — and that users actually have — is 3.2.
String _shellExecutable(String shell) {
  final override = _override('CLIWEAVE_E2E_SHELL_${shell.toUpperCase()}');

  return override ?? defaultShellExecutables[shell]!;
}

/// Reads an override, treating an empty value as unset.
///
/// A workflow matrix that only sets a variable on some lanes still exports it
/// as an empty string everywhere else.
String? _override(String name) {
  final value = Platform.environment[name];

  return value == null || value.isEmpty ? null : value;
}

bool _isPowerShell(String shell) => shellScripts[shell] == 'powershell';

Future<ProcessResult> _fixture(List<String> arguments) {
  return Process.run(fixtureExecutable, arguments);
}

final Map<String, File> _scriptCache = {};

Future<File> _completionScript(String shell) async {
  final scriptName = shellScripts[shell]!;
  final cached = _scriptCache[scriptName];
  if (cached != null) {
    return cached;
  }
  final result = await _fixture(['completion', scriptName]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  final extension = scriptName == 'powershell' ? 'ps1' : scriptName;
  final script = File(p.join(temporaryDirectory.path, 'completion.$extension'))
    ..writeAsStringSync(result.stdout as String);

  return _scriptCache[scriptName] = script;
}

Map<String, String> _environment(String line, File script) {
  final path = Platform.environment['PATH'] ?? '';
  return {
    ...Platform.environment,
    'PATH': '${temporaryDirectory.path}${Platform.isWindows ? ';' : ':'}$path',
    'E2E_LINE': line,
    'E2E_SCRIPT': script.path,
  };
}

Future<ProcessResult> _runShell(
  String shell,
  String command, {
  String line = '',
}) async {
  final script = await _completionScript(shell);
  final arguments = _isPowerShell(shell)
      ? ['-NoProfile', '-Command', command]
      : ['-c', command];

  return Process.run(
    _shellExecutable(shell),
    arguments,
    environment: _environment(line, script),
  );
}

/// Records which binary a lane actually used, so a CI failure says whether it
/// was bash 3.2 or bash 5 that broke.
Future<void> _recordShellVersion(String shell) async {
  final executable = _shellExecutable(shell);
  final result = _isPowerShell(shell)
      ? await Process.run(executable, [
          '-NoProfile',
          '-Command',
          r'$PSVersionTable.PSVersion.ToString()',
        ])
      : await Process.run(executable, ['--version']);
  printOnFailure('$shell -> $executable: ${result.stdout}'.trim());
}

/// Invokes the completion entry point directly, without a terminal.
///
/// bash and zsh have no headless completion API, so their branches drive the
/// generated function the way the shell would. That keeps a precise signal for
/// the script's own logic; the pty tests below cover the registration and
/// rendering this cannot reach.
Future<List<String>> _complete(String shell, String line) async {
  final command = switch (shell) {
    'bash' =>
      r'''
source "$E2E_SCRIPT"
IFS=' ' read -r -a COMP_WORDS <<< "$E2E_LINE"
if [[ "$E2E_LINE" == *" " ]]; then COMP_WORDS+=(""); fi
COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
__cliweave_fixture_complete
printf '%s\n' "${COMPREPLY[@]}"
''',
    'zsh' =>
      r'''
source "$E2E_SCRIPT"
function compadd() {
  local displayName="" expectDisplayName=0 seen=0 arg
  for arg in "$@"; do
    if (( expectDisplayName )); then
      displayName="$arg"
      expectDisplayName=0
    elif [[ "$arg" == "-d" ]]; then
      expectDisplayName=1
    fi
    if (( seen )); then print -r -- "$arg"; fi
    if [[ "$arg" == "--" ]]; then seen=1; fi
  done
  if [[ -n "$displayName" ]]; then
    local -a displays
    displays=("${(@P)displayName}")
    print -rl -- "${displays[@]}"
  fi
}
words=(${=E2E_LINE})
if [[ "$E2E_LINE" == *" " ]]; then words+=(""); fi
CURRENT=${#words[@]}
__cliweave_fixture_complete
''',
    'fish' =>
      r'''
source $E2E_SCRIPT
complete -C "$E2E_LINE"
''',
    'powershell' || 'powershell5' =>
      r'''
. $env:E2E_SCRIPT
$completion = [System.Management.Automation.CommandCompletion]::CompleteInput(
  $env:E2E_LINE,
  $env:E2E_LINE.Length,
  $null
)
$completion.CompletionMatches | ForEach-Object {
  "$($_.CompletionText)`t$($_.ResultType)`t$($_.ToolTip)"
}
''',
    _ => throw ArgumentError('unsupported shell $shell'),
  };
  final result = await _runShell(shell, command, line: line);
  expect(result.exitCode, 0, reason: '${result.stderr}');

  return '${result.stdout}${result.stderr}'
      .split(RegExp(r'\r?\n'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

/// Renders raw pty bytes into the text a person would have seen.
String _renderScreen(String raw) {
  final withoutEscapes = raw
      .replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '')
      .replaceAll(RegExp(r'\x1B[@-Z\\-_]'), '')
      .replaceAll('\x07', '')
      .replaceAll('\r', '\n');
  final rendered = StringBuffer();
  for (final rune in withoutEscapes.runes) {
    if (rune == 0x08) {
      final text = rendered.toString();
      rendered
        ..clear()
        ..write(text.isEmpty ? text : text.substring(0, text.length - 1));
    } else {
      rendered.writeCharCode(rune);
    }
  }

  return rendered.toString();
}

/// The pty host has to be zsh: `zpty` is the only shell builtin that allocates
/// a pty, and bash has no equivalent, so bash is driven as a guest inside it.
String get _ptyHost => _override('CLIWEAVE_E2E_PTY_HOST') ?? 'zsh';

bool get _ptyHostAvailable {
  if (Platform.isWindows) {
    return false;
  }
  try {
    return Process.runSync(_ptyHost, ['-c', 'zmodload zsh/zpty']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Types [line] followed by Tab into a real [shell] session and returns what
/// the terminal showed.
Future<String> _completeInPty(String shell, String line) async {
  final script = await _completionScript(shell);
  final result = await Process.run(_ptyHost, [
    ptyDriver,
    shell,
    _shellExecutable(shell),
    script.path,
    line,
  ], environment: _environment(line, script));
  expect(
    result.exitCode,
    0,
    reason: 'pty driver failed: ${result.stderr}\n${result.stdout}',
  );

  return _renderScreen('${result.stdout}');
}

void main() {
  setUpAll(() async {
    temporaryDirectory = Directory.systemTemp.createTempSync('cliweave-e2e-');
    fixtureExecutable = p.join(
      temporaryDirectory.path,
      Platform.isWindows ? 'cliweave-fixture.exe' : 'cliweave-fixture',
    );
    ptyDriver = p.join(Directory.current.path, 'test', 'e2e', 'pty_driver.zsh');
    final compile = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      'test/e2e/fixture_cli.dart',
      '-o',
      fixtureExecutable,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}');
  });

  tearDownAll(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'compiled CLI runs commands, help, errors, and stdio cursor output',
    () async {
      final deploy = await _fixture(['deploy', '--mode', 'safe', 'src/']);
      final help = await _fixture(['--help']);
      final unknown = await _fixture(['unknown']);
      final stream = await _fixture(['stream']);

      expect(deploy.exitCode, 0);
      expect(deploy.stdout, 'deploy:src/:safe\n');
      expect(help.stdout, contains('Completion fixture'));
      expect(help.stdout, isNot(contains('__complete')));
      expect(unknown.exitCode, isNot(0));
      expect(unknown.stderr, contains('No command registered'));
      expect(stream.stdout, '\x1B[1K\x1B[2K\x1B[0K\x1B[3Gstream\n');
    },
  );

  for (final shell in ['bash', 'zsh', 'fish', 'powershell', 'powershell5']) {
    final skipReason = _selected(shell)
        ? null
        : 'Set CLIWEAVE_E2E_SHELLS to require this shell.';

    test('$shell executes generated completion scripts', () async {
      await _recordShellVersion(shell);

      final describedRoutes = await _complete(shell, 'cliweave-fixture ');
      final route = await _complete(shell, 'cliweave-fixture de');
      final flag = await _complete(shell, 'cliweave-fixture deploy --m');
      final dynamicValue = await _complete(
        shell,
        'cliweave-fixture deploy --project a',
      );
      final directory = await _complete(shell, 'cliweave-fixture deploy s');

      expect(route.join('\n'), contains('deploy'));
      expect(describedRoutes.join('\n'), contains('Deploy a target'));
      expect(flag.join('\n'), contains('--mode'));
      expect(dynamicValue.join('\n'), contains('alpha'));
      expect(directory.join('\n'), contains('src/'));
    }, skip: skipReason);
  }

  test(
    'bash registers the completion function with the documented options',
    () async {
      final result = await _runShell(
        'bash',
        r'source "$E2E_SCRIPT"; complete -p cliweave-fixture',
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        result.stdout,
        contains(
          'complete -o default -o nospace -F ${functionPrefix}_complete '
          '$executableName',
        ),
      );
    },
    skip: _selected('bash')
        ? null
        : 'Set CLIWEAVE_E2E_SHELLS to require this shell.',
  );

  test(
    'zsh registers with compdef and reinstates itself after being displaced',
    () async {
      final result = await _runShell('zsh', '''
source "\$E2E_SCRIPT"
print -r -- "registered=\${_comps[$executableName]}"
_comps[$executableName]=_files
print -r -- "displaced=\${_comps[$executableName]}"
${functionPrefix}_ensure_completion
print -r -- "restored=\${_comps[$executableName]}"
''');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('registered=${functionPrefix}_complete'));
      expect(result.stdout, contains('displaced=_files'));
      expect(result.stdout, contains('restored=${functionPrefix}_complete'));
    },
    skip: _selected('zsh')
        ? null
        : 'Set CLIWEAVE_E2E_SHELLS to require this shell.',
  );

  test(
    'powershell marks directory candidates as containers',
    () async {
      final shell = _selected('powershell5') ? 'powershell5' : 'powershell';
      final directory = await _complete(shell, 'cliweave-fixture deploy s');
      final flag = await _complete(shell, 'cliweave-fixture deploy --m');

      expect(directory.join('\n'), contains('src/\tProviderContainer'));
      expect(flag.join('\n'), contains('--mode\tParameterValue'));
    },
    skip: _selected('powershell') || _selected('powershell5')
        ? null
        : 'Set CLIWEAVE_E2E_SHELLS to require a PowerShell host.',
  );

  for (final shell in ['bash', 'zsh']) {
    final skipReason = !_selected(shell)
        ? 'Set CLIWEAVE_E2E_SHELLS to require this shell.'
        : !_ptyHostAvailable
        ? 'Needs a zsh with zsh/zpty to host the pty.'
        : null;

    test(
      '$shell completes a real Tab keypress through its own registration',
      () async {
        await _recordShellVersion(shell);

        final describedRoutes = await _completeInPty(
          shell,
          'cliweave-fixture ',
        );
        final route = await _completeInPty(shell, 'cliweave-fixture de');
        final flag = await _completeInPty(shell, 'cliweave-fixture deploy --m');
        final dynamicValue = await _completeInPty(
          shell,
          'cliweave-fixture deploy --project a',
        );
        final directory = await _completeInPty(
          shell,
          'cliweave-fixture deploy s',
        );

        printOnFailure('routes screen:\n$describedRoutes');

        // Descriptions are rendered next to their candidate, not just returned.
        expect(describedRoutes, contains('deploy'));
        expect(describedRoutes, contains('Deploy a target'));
        expect(describedRoutes, contains('Exercise the stdio adapter'));

        // A unique candidate is inserted with a trailing space, ...
        expect(route, contains('cliweave-fixture deploy '));
        expect(flag, contains('deploy --mode '));
        expect(dynamicValue, contains('--project alpha '));

        // ... while a directory candidate keeps the cursor on the slash.
        expect(directory, contains('deploy src/'));
        expect(directory, isNot(contains('src/ ')));
      },
      skip: skipReason,
    );
  }
}
