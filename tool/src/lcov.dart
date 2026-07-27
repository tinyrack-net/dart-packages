import 'dart:io';

const double minimumPackageLineCoverage = 95;

final class LcovFileCoverage {
  const LcovFileCoverage({
    required this.source,
    required this.linesFound,
    required this.linesHit,
    required this.missedLines,
  });

  final String source;
  final int linesFound;
  final int linesHit;
  final List<int> missedLines;
}

final class LcovCoverage {
  const LcovCoverage(this.files);

  final List<LcovFileCoverage> files;

  int get linesFound => files.fold(0, (total, file) => total + file.linesFound);

  int get linesHit => files.fold(0, (total, file) => total + file.linesHit);

  double get percentage => linesFound == 0 ? 0 : linesHit * 100 / linesFound;

  bool meets(double minimum) =>
      linesFound > 0 && percentage + 0.0000001 >= minimum;
}

LcovCoverage parseLcov(String contents) {
  final files = <LcovFileCoverage>[];
  String? source;
  int? linesFound;
  int? linesHit;
  var missedLines = <int>[];

  Never malformed(String message) {
    throw FormatException('Invalid LCOV: $message');
  }

  void finishRecord() {
    if (source == null && linesFound == null && linesHit == null) {
      malformed('empty record');
    }
    if (source == null || linesFound == null || linesHit == null) {
      malformed('record is missing SF, LF, or LH');
    }
    if (linesHit! > linesFound!) {
      malformed('LH cannot exceed LF for $source');
    }
    files.add(
      LcovFileCoverage(
        source: source!,
        linesFound: linesFound!,
        linesHit: linesHit!,
        missedLines: List.unmodifiable(missedLines),
      ),
    );
    source = null;
    linesFound = null;
    linesHit = null;
    missedLines = <int>[];
  }

  for (final rawLine in contents.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('TN:')) {
      continue;
    }
    if (line.startsWith('SF:')) {
      if (source != null) {
        malformed('record started before the previous record ended');
      }
      source = line.substring(3);
      if (source!.isEmpty) {
        malformed('SF is empty');
      }
    } else if (line.startsWith('DA:')) {
      final values = line.substring(3).split(',');
      if (values.length < 2) {
        malformed('invalid DA entry');
      }
      final lineNumber = int.tryParse(values[0]);
      final hits = int.tryParse(values[1]);
      if (lineNumber == null || hits == null || lineNumber < 1 || hits < 0) {
        malformed('invalid DA values');
      }
      if (hits == 0) {
        missedLines.add(lineNumber);
      }
    } else if (line.startsWith('LF:')) {
      linesFound = int.tryParse(line.substring(3));
      if (linesFound == null || linesFound! < 0) {
        malformed('invalid LF');
      }
    } else if (line.startsWith('LH:')) {
      linesHit = int.tryParse(line.substring(3));
      if (linesHit == null || linesHit! < 0) {
        malformed('invalid LH');
      }
    } else if (line == 'end_of_record') {
      finishRecord();
    }
  }

  if (source != null || linesFound != null || linesHit != null) {
    malformed('unterminated record');
  }
  if (files.isEmpty) {
    malformed('no file records');
  }
  return LcovCoverage(List.unmodifiable(files));
}

LcovCoverage readLcov(File file) {
  if (!file.existsSync()) {
    throw FileSystemException('LCOV file does not exist', file.path);
  }
  return parseLcov(file.readAsStringSync());
}
