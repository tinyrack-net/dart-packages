import 'dart:io';

/// Deterministically combines independently collected LCOV tracefiles.
final class LcovMerger {
  const LcovMerger();

  /// Merges [inputPaths] into one canonical tracefile at [outputPath].
  void mergeFiles(List<String> inputPaths, String outputPath) {
    if (inputPaths.isEmpty) {
      throw const FormatException('At least one LCOV input is required.');
    }
    final records = <String, _LcovRecord>{};
    for (final path in inputPaths) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('Coverage report not found: $path');
      }
      _parse(file.readAsLinesSync(), path, records);
    }
    final sources = records.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final source in sources) {
      final record = records[source]!;
      buffer.writeln('SF:$source');
      final functions = record.functionLines.keys.toList()..sort();
      for (final name in functions) {
        buffer.writeln('FN:${record.functionLines[name]},$name');
      }
      for (final name in functions) {
        buffer.writeln('FNDA:${record.functionHits[name] ?? 0},$name');
      }
      if (functions.isNotEmpty) {
        buffer
          ..writeln('FNF:${functions.length}')
          ..writeln(
            'FNH:${functions.where((name) => (record.functionHits[name] ?? 0) > 0).length}',
          );
      }
      final lines = record.lineHits.keys.toList()..sort();
      for (final line in lines) {
        buffer.writeln('DA:$line,${record.lineHits[line]}');
      }
      final branches = record.branchHits.keys.toList()..sort();
      for (final branch in branches) {
        final hits = record.branchHits[branch]!;
        buffer.writeln(
          'BRDA:${branch.line},${branch.block},${branch.branch},$hits',
        );
      }
      buffer
        ..writeln('LF:${lines.length}')
        ..writeln(
          'LH:${lines.where((line) => record.lineHits[line]! > 0).length}',
        )
        ..writeln('BRF:${branches.length}')
        ..writeln(
          'BRH:${branches.where((branch) => record.branchHits[branch]! > 0).length}',
        )
        ..writeln('end_of_record');
    }
    final output = File(outputPath)..parent.createSync(recursive: true);
    output.writeAsStringSync(buffer.toString());
  }

  void _parse(
    List<String> lines,
    String path,
    Map<String, _LcovRecord> records,
  ) {
    _LcovRecord? current;
    var ended = true;
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index].trim();
      if (line.isEmpty || line.startsWith('TN:')) continue;
      if (line.startsWith('SF:')) {
        if (!ended) {
          throw FormatException('Missing end_of_record in $path:${index + 1}');
        }
        final source = line.substring(3);
        if (source.isEmpty) {
          throw FormatException('Empty source path in $path:${index + 1}');
        }
        current = records.putIfAbsent(source, _LcovRecord.new);
        ended = false;
      } else if (line == 'end_of_record') {
        if (current == null || ended) {
          throw FormatException(
            'Unexpected end_of_record in $path:${index + 1}',
          );
        }
        ended = true;
        current = null;
      } else if (current == null || ended) {
        throw FormatException('LCOV data precedes SF in $path:${index + 1}');
      } else if (line.startsWith('DA:')) {
        final fields = line.substring(3).split(',');
        if (fields.length < 2) _malformed(path, index, line);
        final number = int.tryParse(fields[0]);
        final hits = int.tryParse(fields[1]);
        if (number == null || hits == null) _malformed(path, index, line);
        current.lineHits.update(
          number,
          (value) => value + hits,
          ifAbsent: () => hits,
        );
      } else if (line.startsWith('BRDA:')) {
        final fields = line.substring(5).split(',');
        if (fields.length != 4) _malformed(path, index, line);
        final number = int.tryParse(fields[0]);
        if (number == null) _malformed(path, index, line);
        final key = _BranchKey(number, fields[1], fields[2]);
        final hits = fields[3] == '-' ? 0 : int.tryParse(fields[3]);
        if (hits == null) _malformed(path, index, line);
        current.branchHits.update(
          key,
          (value) => value + hits,
          ifAbsent: () => hits,
        );
      } else if (line.startsWith('FN:')) {
        final fields = line.substring(3).split(',');
        if (fields.length < 2) _malformed(path, index, line);
        final number = int.tryParse(fields.first);
        final name = fields.skip(1).join(',');
        if (number == null || name.isEmpty) _malformed(path, index, line);
        current.functionLines[name] = number;
      } else if (line.startsWith('FNDA:')) {
        final fields = line.substring(5).split(',');
        if (fields.length < 2) _malformed(path, index, line);
        final hits = int.tryParse(fields.first);
        final name = fields.skip(1).join(',');
        if (hits == null || name.isEmpty) _malformed(path, index, line);
        current.functionHits.update(
          name,
          (value) => value + hits,
          ifAbsent: () => hits,
        );
      } else if (!_summaryPrefixes.any(line.startsWith)) {
        throw FormatException(
          'Unsupported LCOV data in $path:${index + 1}: $line',
        );
      }
    }
    if (!ended) throw FormatException('Missing end_of_record at end of $path');
  }

  Never _malformed(String path, int zeroBasedLine, String value) =>
      throw FormatException(
        'Malformed LCOV data in $path:${zeroBasedLine + 1}: $value',
      );
}

const _summaryPrefixes = <String>['LF:', 'LH:', 'BRF:', 'BRH:', 'FNF:', 'FNH:'];

final class _LcovRecord {
  final Map<int, int> lineHits = <int, int>{};
  final Map<_BranchKey, int> branchHits = <_BranchKey, int>{};
  final Map<String, int> functionLines = <String, int>{};
  final Map<String, int> functionHits = <String, int>{};
}

final class _BranchKey implements Comparable<_BranchKey> {
  const _BranchKey(this.line, this.block, this.branch);

  final int line;
  final String block;
  final String branch;

  @override
  int compareTo(_BranchKey other) {
    final lineOrder = line.compareTo(other.line);
    if (lineOrder != 0) return lineOrder;
    final blockOrder = block.compareTo(other.block);
    return blockOrder != 0 ? blockOrder : branch.compareTo(other.branch);
  }

  @override
  bool operator ==(Object other) =>
      other is _BranchKey &&
      line == other.line &&
      block == other.block &&
      branch == other.branch;

  @override
  int get hashCode => Object.hash(line, block, branch);
}
