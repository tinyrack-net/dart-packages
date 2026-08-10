import 'dart:io';

import 'src/lcov.dart';

final class _PackageCoverage {
  const _PackageCoverage({
    required this.name,
    required this.testArguments,
    this.minimumLineCoverage = minimumPackageLineCoverage,
  });

  final String name;
  final List<String> testArguments;

  /// Line-coverage floor for this package.
  ///
  /// Defaults to the repository gate. A package sets its own only with a
  /// reason recorded where it is set.
  final double minimumLineCoverage;
}

Future<int> _run(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

Future<void> main(List<String> arguments) async {
  final root = File.fromUri(Platform.script).parent.parent.absolute;
  final outputRoot = Directory.fromUri(root.uri.resolve('coverage/'));
  if (outputRoot.existsSync()) {
    outputRoot.deleteSync(recursive: true);
  }
  outputRoot.createSync(recursive: true);

  // `shipworld` is checked on a Windows runner because its Windows SDK-tool
  // discovery is guarded by `Platform.isWindows`; the others are checked on
  // Linux. `ptyworld` runs its own job because it builds a C native asset, so
  // a toolchain failure there must not be confused with a coverage regression
  // in the pure-Dart packages. Passing package names restricts the run.
  const allPackages = [
    _PackageCoverage(name: 'cliweave', testArguments: ['-x', 'e2e']),
    _PackageCoverage(name: 'dartage', testArguments: ['-x', 'interop']),
    _PackageCoverage(name: 'lua_tool_runtime', testArguments: []),
    _PackageCoverage(name: 'ptyworld', testArguments: []),
    _PackageCoverage(name: 'shipworld', testArguments: []),
    // `vtworld` was extracted from `termworld`, which gates at 90% line and
    // 80% branch coverage. The lines it misses here are the ones its Flutter
    // half covers: renderer hooks, view-element attachment, focus handlers,
    // and the option setters only a widget calls. Re-covering those from a
    // headless package would test nothing a consumer can reach, so the floor
    // matches the gate the code was written against instead.
    _PackageCoverage(
      name: 'vtworld',
      testArguments: [],
      minimumLineCoverage: 90,
    ),
  ];
  final packages = arguments.isEmpty
      ? allPackages
      : allPackages.where((p) => arguments.contains(p.name)).toList();
  if (packages.isEmpty) {
    stderr.writeln('No matching packages for: ${arguments.join(', ')}');
    exitCode = 64;
    return;
  }
  var failed = false;

  for (final package in packages) {
    final packageDirectory = Directory.fromUri(
      root.uri.resolve('packages/${package.name}/'),
    );
    final outputDirectory = Directory.fromUri(
      outputRoot.uri.resolve('${package.name}/'),
    )..createSync(recursive: true);
    final lcov = File.fromUri(outputDirectory.uri.resolve('lcov.info'));

    stdout.writeln('\n== ${package.name} coverage ==');
    final exitCode = await _run(Platform.resolvedExecutable, [
      'test',
      '--coverage-path=${lcov.path}',
      '-r',
      'failures-only',
      ...package.testArguments,
    ], workingDirectory: packageDirectory.path);
    if (exitCode != 0) {
      failed = true;
      continue;
    }

    final coverage = readLcov(lcov);
    stdout.writeln(
      '${coverage.linesHit}/${coverage.linesFound} lines '
      '(${coverage.percentage.toStringAsFixed(2)}%)',
    );
    for (final file in coverage.files.where(
      (file) => file.missedLines.isNotEmpty,
    )) {
      final sourceName = Uri.file(file.source).pathSegments.last;
      stdout.writeln('  $sourceName: missed ${file.missedLines.join(', ')}');
    }
    if (!coverage.meets(package.minimumLineCoverage)) {
      stderr.writeln(
        '${package.name} coverage is below '
        '${package.minimumLineCoverage.toStringAsFixed(0)}%.',
      );
      failed = true;
    }
  }

  if (failed) {
    exitCode = 1;
    return;
  }
  stdout.writeln('\nEvery package meets its line coverage gate.');
}
