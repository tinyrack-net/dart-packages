import 'dart:io';

import 'src/lcov.dart';

final class _PackageCoverage {
  const _PackageCoverage({required this.name, required this.testArguments});

  final String name;
  final List<String> testArguments;
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
  // Linux. Passing package names restricts the run to those packages.
  const allPackages = [
    _PackageCoverage(name: 'cliweave', testArguments: ['-x', 'e2e']),
    _PackageCoverage(name: 'dartage', testArguments: ['-x', 'interop']),
    _PackageCoverage(name: 'shipworld', testArguments: []),
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
    if (!coverage.meets(minimumPackageLineCoverage)) {
      stderr.writeln(
        '${package.name} coverage is below '
        '${minimumPackageLineCoverage.toStringAsFixed(0)}%.',
      );
      failed = true;
    }
  }

  if (failed) {
    exitCode = 1;
    return;
  }
  stdout.writeln(
    '\nEvery package meets the '
    '${minimumPackageLineCoverage.toStringAsFixed(0)}% line coverage gate.',
  );
}
