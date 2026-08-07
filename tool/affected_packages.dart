import 'dart:convert';
import 'dart:io';

import 'src/affected.dart';

/// Decides which workspace members a change set has to test.
///
/// Reads changed file paths, one per line, from stdin or from the file named by
/// `--changed-files <path>`, and writes the verdict as JSON on stdout. When
/// `GITHUB_OUTPUT` is set it also appends `<package>=true|false` lines plus an
/// `all=` line, which is what `ci.yml` gates its jobs on.
///
/// Pass `--all` to skip the change set and mark every member affected; the
/// workflow uses that for `push` and `merge_group`, where the full suite runs
/// regardless of the diff.
///
/// This imports nothing outside `dart:*`, so it runs before `dart pub get`.
Future<void> main(List<String> arguments) async {
  final root = File.fromUri(Platform.script).parent.parent.absolute;
  final packages = readWorkspace(root);

  final AffectedPackages affected;
  if (arguments.contains('--all')) {
    affected = AffectedPackages(
      everything: true,
      names: packages.map((package) => package.name).toSet(),
    );
  } else {
    final changed = await _readChangedPaths(arguments);
    if (changed == null) {
      stderr.writeln(
        'usage: dart run tool/affected_packages.dart '
        '[--all | --changed-files <path>]',
      );
      exitCode = 64;
      return;
    }
    affected = resolveAffected(packages, changed);
  }

  final verdict = <String, Object?>{
    'all': affected.everything,
    for (final package in packages)
      package.name: affected.contains(package.name),
  };

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(verdict));

  final githubOutput = Platform.environment['GITHUB_OUTPUT'];
  if (githubOutput != null && githubOutput.isNotEmpty) {
    File(githubOutput).writeAsStringSync(
      verdict.entries.map((entry) => '${entry.key}=${entry.value}\n').join(),
      mode: FileMode.append,
    );
  }
}

/// Returns the changed paths, or `null` when `--changed-files` names no file.
Future<List<String>?> _readChangedPaths(List<String> arguments) async {
  final flag = arguments.indexOf('--changed-files');
  if (flag == -1) {
    return (await stdin.transform(utf8.decoder).join()).split('\n');
  }
  if (flag + 1 >= arguments.length) {
    return null;
  }
  return File(arguments[flag + 1]).readAsLinesSync();
}
