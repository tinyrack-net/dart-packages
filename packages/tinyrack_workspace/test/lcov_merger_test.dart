import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tinyrack_workspace/tinyrack_workspace.dart';

void main() {
  test('merges line and branch identities deterministically', () {
    final root = Directory.systemTemp.createTempSync('lcov-merge-');
    addTearDown(() => root.deleteSync(recursive: true));
    final first = File(p.join(root.path, 'first.info'))
      ..writeAsStringSync('''
SF:lib/a.dart
DA:1,1
DA:2,0
BRDA:2,0,0,1
BRDA:2,0,1,-
LF:2
LH:1
BRF:2
BRH:1
end_of_record
''');
    final second = File(p.join(root.path, 'second.info'))
      ..writeAsStringSync('''
SF:lib/a.dart
DA:1,2
DA:2,1
BRDA:2,0,0,2
BRDA:2,0,1,1
end_of_record
SF:lib/b.dart
DA:3,1
end_of_record
''');
    final output = File(p.join(root.path, 'merged.info'));

    const LcovMerger().mergeFiles(<String>[
      first.path,
      second.path,
    ], output.path);

    expect(output.readAsStringSync(), '''
SF:lib/a.dart
DA:1,3
DA:2,1
BRDA:2,0,0,3
BRDA:2,0,1,1
LF:2
LH:2
BRF:2
BRH:2
end_of_record
SF:lib/b.dart
DA:3,1
LF:1
LH:1
BRF:0
BRH:0
end_of_record
''');
  });

  test('rejects missing and malformed reports', () {
    final root = Directory.systemTemp.createTempSync('lcov-merge-invalid-');
    addTearDown(() => root.deleteSync(recursive: true));
    final malformed = File(p.join(root.path, 'bad.info'))
      ..writeAsStringSync('DA:1,1\n');

    expect(
      () => const LcovMerger().mergeFiles(<String>[
        p.join(root.path, 'missing.info'),
      ], p.join(root.path, 'out.info')),
      throwsStateError,
    );
    expect(
      () => const LcovMerger().mergeFiles(<String>[
        malformed.path,
      ], p.join(root.path, 'out.info')),
      throwsFormatException,
    );
  });

  test('merges function counters and validates every record boundary', () {
    final root = Directory.systemTemp.createTempSync('lcov-functions-');
    addTearDown(() => root.deleteSync(recursive: true));
    final first = File(p.join(root.path, 'functions.info'))
      ..writeAsStringSync('''
TN:suite
SF:lib/a.dart
FN:3,answer
FNDA:1,answer
DA:3,1,checksum
FNF:1
FNH:1
end_of_record
''');
    final second = File(p.join(root.path, 'functions-2.info'))
      ..writeAsStringSync('''
SF:lib/a.dart
FN:3,answer
FNDA:2,answer
DA:3,2
end_of_record
''');
    final output = File(p.join(root.path, 'merged.info'));

    const LcovMerger().mergeFiles(<String>[
      first.path,
      second.path,
    ], output.path);
    expect(output.readAsStringSync(), contains('FNDA:3,answer'));

    for (final contents in <String>[
      'end_of_record\n',
      'SF:\nend_of_record\n',
      'SF:lib/a.dart\nDA:bad\nend_of_record\n',
      'SF:lib/a.dart\nBRDA:bad\nend_of_record\n',
      'SF:lib/a.dart\nBRDA:x,0,0,1\nend_of_record\n',
      'SF:lib/a.dart\nBRDA:1,0,0,x\nend_of_record\n',
      'SF:lib/a.dart\nFN:bad\nend_of_record\n',
      'SF:lib/a.dart\nFN:x,name\nend_of_record\n',
      'SF:lib/a.dart\nFNDA:bad\nend_of_record\n',
      'SF:lib/a.dart\nFNDA:x,name\nend_of_record\n',
      'SF:lib/a.dart\nUNKNOWN:value\nend_of_record\n',
      'SF:lib/a.dart\nSF:lib/b.dart\nend_of_record\n',
      'SF:lib/a.dart\n',
    ]) {
      final invalid = File(p.join(root.path, 'invalid.info'))
        ..writeAsStringSync(contents);
      expect(
        () =>
            const LcovMerger().mergeFiles(<String>[invalid.path], output.path),
        throwsFormatException,
        reason: contents,
      );
    }
    expect(
      () => const LcovMerger().mergeFiles(const <String>[], output.path),
      throwsFormatException,
    );
  });
}
