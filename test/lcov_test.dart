import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/lcov.dart';

String _record(String source, int found, int hit) =>
    '''
SF:$source
DA:1,${hit > 0 ? 1 : 0}
LF:$found
LH:$hit
end_of_record
''';

void main() {
  test('accepts exactly 95 percent', () {
    final coverage = parseLcov(_record('lib/example.dart', 20, 19));

    expect(coverage.percentage, 95);
    expect(coverage.meets(minimumPackageLineCoverage), isTrue);
  });

  test('rejects less than 95 percent', () {
    final coverage = parseLcov(_record('lib/example.dart', 20, 18));

    expect(coverage.percentage, 90);
    expect(coverage.meets(minimumPackageLineCoverage), isFalse);
  });

  test('keeps package results independent instead of aggregating them', () {
    final high = parseLcov(_record('lib/high.dart', 100, 100));
    final low = parseLcov(_record('lib/low.dart', 100, 90));

    expect(high.meets(minimumPackageLineCoverage), isTrue);
    expect(low.meets(minimumPackageLineCoverage), isFalse);
  });

  test('reports missed source lines', () {
    final coverage = parseLcov('''
SF:lib/example.dart
DA:4,1
DA:8,0
DA:9,0
LF:3
LH:1
end_of_record
''');

    expect(coverage.files.single.missedLines, [8, 9]);
  });

  test('rejects empty and malformed reports', () {
    expect(() => parseLcov(''), throwsFormatException);
    expect(
      () => parseLcov('SF:lib/example.dart\nLF:1\nend_of_record\n'),
      throwsFormatException,
    );
    expect(
      () => parseLcov(_record('lib/example.dart', 1, 2)),
      throwsFormatException,
    );
  });

  test('rejects a missing report', () {
    final missing = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'missing-lcov-${DateTime.now().microsecondsSinceEpoch}.info',
    );

    expect(() => readLcov(missing), throwsA(isA<FileSystemException>()));
  });
}
