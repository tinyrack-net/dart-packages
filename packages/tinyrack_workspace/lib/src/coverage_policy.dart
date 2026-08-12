import 'dart:io';

import 'package:path/path.dart' as p;

/// Coverage totals for one package.
final class CoverageTotals {
  const CoverageTotals({
    required this.linesFound,
    required this.linesHit,
    required this.branchesFound,
    required this.branchesHit,
    required this.missingFiles,
  });

  final int linesFound;
  final int linesHit;
  final int branchesFound;
  final int branchesHit;
  final List<String> missingFiles;

  double get lineRate => linesFound == 0 ? 0 : linesHit / linesFound;
  double get branchRate => branchesFound == 0 ? 0 : branchesHit / branchesFound;
}

/// Reads LCOV and enforces line, branch, and source-presence policy.
final class CoveragePolicy {
  const CoveragePolicy({
    this.minimumLineRate = 0.9,
    this.minimumBranchRate = 0.8,
  });

  final double minimumLineRate;
  final double minimumBranchRate;

  CoverageTotals calculate(String packageDirectory) {
    final root = p.normalize(p.absolute(packageDirectory));
    final report = File(p.join(root, 'coverage', 'lcov.info'));
    if (!report.existsSync()) {
      throw StateError('Coverage report not found: ${report.path}');
    }
    final records = _parseLcov(report.readAsLinesSync(), root);
    var linesFound = 0;
    var linesHit = 0;
    var branchesFound = 0;
    var branchesHit = 0;
    final missing = <String>[];
    for (final source in _productionSources(root)) {
      final record = records[source];
      if (record == null) {
        final estimated = _estimatedExecutableLines(File(source));
        if (estimated > 0) {
          linesFound += estimated;
          missing.add(p.relative(source, from: root));
        }
        continue;
      }
      linesFound += record.linesFound;
      linesHit += record.linesHit;
      branchesFound += record.branchesFound;
      branchesHit += record.branchesHit;
    }
    return CoverageTotals(
      linesFound: linesFound,
      linesHit: linesHit,
      branchesFound: branchesFound,
      branchesHit: branchesHit,
      missingFiles: List<String>.unmodifiable(missing),
    );
  }

  String? validate(String packageName, CoverageTotals totals) {
    if (totals.lineRate >= minimumLineRate &&
        totals.branchRate >= minimumBranchRate &&
        totals.missingFiles.isEmpty) {
      return null;
    }
    final missing = totals.missingFiles.isEmpty
        ? ''
        : ' missing=${totals.missingFiles.join(',')}';
    return '$packageName: line=${_percent(totals.lineRate)} '
        'branch=${_percent(totals.branchRate)}$missing';
  }

  Map<String, _CoverageRecord> _parseLcov(List<String> lines, String root) {
    final records = <String, _CoverageRecord>{};
    String? source;
    var linesFound = 0;
    var linesHit = 0;
    var branchesFound = 0;
    var branchesHit = 0;

    void finish() {
      if (source == null) return;
      final sourcePath = source!;
      records[p.normalize(
        p.isAbsolute(sourcePath) ? sourcePath : p.join(root, sourcePath),
      )] = _CoverageRecord(
        linesFound,
        linesHit,
        branchesFound,
        branchesHit,
      );
      source = null;
      linesFound = 0;
      linesHit = 0;
      branchesFound = 0;
      branchesHit = 0;
    }

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        finish();
        source = line.substring(3);
      } else if (line.startsWith('LF:')) {
        linesFound = int.parse(line.substring(3));
      } else if (line.startsWith('LH:')) {
        linesHit = int.parse(line.substring(3));
      } else if (line.startsWith('BRF:')) {
        branchesFound = int.parse(line.substring(4));
      } else if (line.startsWith('BRH:')) {
        branchesHit = int.parse(line.substring(4));
      } else if (line.startsWith('BRDA:')) {
        branchesFound += 1;
        final count = line.substring(line.lastIndexOf(',') + 1);
        if (count != '-' && int.parse(count) > 0) branchesHit += 1;
      } else if (line == 'end_of_record') {
        finish();
      }
    }
    finish();
    return records;
  }

  List<String> _productionSources(String root) {
    final lib = Directory(p.join(root, 'lib'));
    if (!lib.existsSync()) return const <String>[];
    final generatedL10n = '${p.separator}l10n${p.separator}gen${p.separator}';
    return <String>[
      for (final entity in lib.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.endsWith('.g.dart') &&
            !entity.path.endsWith('.freezed.dart') &&
            !entity.path.contains(generatedL10n))
          p.normalize(p.absolute(entity.path)),
    ]..sort();
  }

  int _estimatedExecutableLines(File file) {
    final lines = file.readAsLinesSync();
    final code = lines
        .where((line) => !line.trim().startsWith('//'))
        .join('\n');
    final executable = RegExp(
      r'=>|\b(await|return|throw|if|switch|try|for|while)\b|\bmain\s*\(',
    ).hasMatch(code);
    if (!executable) return 0;
    return lines.where((line) {
      final value = line.trim();
      return value.isNotEmpty &&
          !value.startsWith('//') &&
          value != '{' &&
          value != '}' &&
          value != ');' &&
          !value.startsWith('import ') &&
          !value.startsWith('export ') &&
          !value.startsWith('part ');
    }).length;
  }

  String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';
}

/// Discovers packages below conventional workspace directories.
final class CoverageWorkspace {
  const CoverageWorkspace(this.root);

  final String root;

  List<String> packageDirectories({Set<String> scopes = const <String>{}}) {
    final directories = <String>[..._children('apps'), ..._children('packages')]
      ..sort();
    if (scopes.isEmpty) return directories;
    final available = directories.map(p.basename).toSet();
    final unknown = scopes.difference(available).toList()..sort();
    if (unknown.isNotEmpty) throw UnknownCoverageScope(unknown);
    return directories
        .where((directory) => scopes.contains(p.basename(directory)))
        .toList(growable: false);
  }

  Iterable<String> _children(String name) {
    final directory = Directory(p.join(root, name));
    if (!directory.existsSync()) return const <String>[];
    return directory
        .listSync()
        .whereType<Directory>()
        .where((entry) => File(p.join(entry.path, 'pubspec.yaml')).existsSync())
        .map((entry) => entry.path);
  }
}

final class UnknownCoverageScope implements Exception {
  const UnknownCoverageScope(this.scopes);

  final List<String> scopes;

  @override
  String toString() => 'Unknown coverage package scope: ${scopes.join(', ')}';
}

final class _CoverageRecord {
  const _CoverageRecord(
    this.linesFound,
    this.linesHit,
    this.branchesFound,
    this.branchesHit,
  );

  final int linesFound;
  final int linesHit;
  final int branchesFound;
  final int branchesHit;
}
