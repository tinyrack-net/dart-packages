@Tags(['e2e'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

late Directory temporaryDirectory;
late String fixtureExecutable;

Set<String> get requiredShells {
  return (Platform.environment['CLIWEAVE_E2E_SHELLS'] ?? '')
      .split(',')
      .map((shell) => shell.trim().toLowerCase())
      .where((shell) => shell.isNotEmpty)
      .toSet();
}

String _shellExecutable(String shell) {
  return switch (shell) {
    'powershell' => 'pwsh',
    _ => shell,
  };
}

Future<ProcessResult> _fixture(List<String> arguments) {
  return Process.run(fixtureExecutable, arguments);
}

Future<File> _completionScript(String shell) async {
  final result = await _fixture(['completion', shell]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  final extension = shell == 'powershell' ? 'ps1' : shell;
  return File(p.join(temporaryDirectory.path, 'completion.$extension'))
    ..writeAsStringSync(result.stdout as String);
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

Future<List<String>> _complete(String shell, String line) async {
  final script = await _completionScript(shell);
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
  local seen=0 arg
  for arg in "$@"; do
    if (( seen )); then print -r -- "$arg"; fi
    if [[ "$arg" == "--" ]]; then seen=1; fi
  done
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
    'powershell' =>
      r'''
. $env:E2E_SCRIPT
$completion = [System.Management.Automation.CommandCompletion]::CompleteInput(
  $env:E2E_LINE,
  $env:E2E_LINE.Length,
  $null
)
$completion.CompletionMatches | ForEach-Object {
  "$($_.CompletionText)`t$($_.ToolTip)"
}
''',
    _ => throw ArgumentError('unsupported shell $shell'),
  };
  final arguments = shell == 'powershell'
      ? ['-NoProfile', '-Command', command]
      : ['-c', command];
  final result = await Process.run(
    _shellExecutable(shell),
    arguments,
    environment: _environment(line, script),
  );
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return (result.stdout as String)
      .split(RegExp(r'\r?\n'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

bool _selected(String shell) => requiredShells.contains(shell);

void main() {
  setUpAll(() async {
    temporaryDirectory = Directory.systemTemp.createTempSync('cliweave-e2e-');
    fixtureExecutable = p.join(
      temporaryDirectory.path,
      Platform.isWindows ? 'cliweave-fixture.exe' : 'cliweave-fixture',
    );
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

  for (final shell in ['bash', 'zsh', 'fish', 'powershell']) {
    test(
      '$shell executes generated completion scripts',
      () async {
        final route = await _complete(shell, 'cliweave-fixture de');
        final flag = await _complete(shell, 'cliweave-fixture deploy --m');
        final dynamicValue = await _complete(
          shell,
          'cliweave-fixture deploy --project a',
        );
        final directory = await _complete(shell, 'cliweave-fixture deploy s');

        expect(route.join('\n'), contains('deploy'));
        expect(route.join('\n'), contains('Deploy a target'));
        expect(flag.join('\n'), contains('--mode'));
        expect(dynamicValue.join('\n'), contains('alpha'));
        expect(directory.join('\n'), contains('src/'));
      },
      skip: _selected(shell)
          ? false
          : 'Set CLIWEAVE_E2E_SHELLS to require this shell.',
    );
  }
}
