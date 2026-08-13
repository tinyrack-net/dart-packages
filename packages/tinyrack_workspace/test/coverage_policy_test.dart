import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tinyrack_workspace/tinyrack_workspace.dart';

void main() {
  test('calculates line and branch totals and validates both thresholds', () {
    final package = _package('alpha');
    _source(package, 'covered.dart', 'int answer(bool yes) => yes ? 42 : 0;');
    _lcov(package, '''
SF:lib/covered.dart
LF:10
LH:9
BRF:10
BRH:8
end_of_record
''');
    const policy = CoveragePolicy();

    final totals = policy.calculate(package.path);

    expect(totals.lineRate, 0.9);
    expect(totals.branchRate, 0.8);
    expect(policy.validate('alpha', totals), isNull);
    expect(
      const CoveragePolicy(minimumLineRate: 0.91).validate('alpha', totals),
      contains('line=90.0%'),
    );
    expect(
      const CoveragePolicy(minimumBranchRate: 0.81).validate('alpha', totals),
      contains('branch=80.0%'),
    );
  });

  test('counts BRDA entries when summary branch fields are absent', () {
    final package = _package('alpha');
    _source(package, 'covered.dart', 'int answer(bool yes) => yes ? 42 : 0;');
    _lcov(package, '''
SF:${p.join(package.path, 'lib', 'covered.dart')}
LF:1
LH:1
BRDA:1,0,0,1
BRDA:1,0,1,-
end_of_record
''');

    final totals = const CoveragePolicy().calculate(package.path);
    expect((totals.branchesFound, totals.branchesHit), (2, 1));
  });

  test('missing executable production files fail while interfaces do not', () {
    final package = _package('alpha');
    _source(package, 'covered.dart', 'int covered() => 1;');
    _source(package, 'missing.dart', 'int missing() => 2;');
    _source(package, 'interface.dart', 'abstract interface class Port {}');
    _source(package, 'ignored.g.dart', 'int generated() => 3;');
    _lcov(package, '''
SF:lib/covered.dart
LF:1
LH:1
BRF:1
BRH:1
end_of_record
''');

    final totals = const CoveragePolicy().calculate(package.path);
    expect(totals.missingFiles, <String>[p.join('lib', 'missing.dart')]);
    expect(
      const CoveragePolicy().validate('alpha', totals),
      contains('missing=lib${p.separator}missing.dart'),
    );
  });

  test('reports a missing LCOV file', () {
    final package = _package('alpha');
    expect(
      () => const CoveragePolicy().calculate(package.path),
      throwsStateError,
    );
  });

  test('workspace discovers apps and packages and validates scopes', () {
    final root = _temporary();
    for (final path in <String>['apps/ui', 'packages/api', 'packages/empty']) {
      final directory = Directory(p.join(root.path, path))
        ..createSync(recursive: true);
      if (!path.endsWith('empty')) {
        File(p.join(directory.path, 'pubspec.yaml'))
            .writeAsStringSync('name: x');
      }
    }
    final workspace = CoverageWorkspace(root.path);

    expect(workspace.packageDirectories().map(p.basename), <String>[
      'ui',
      'api',
    ]);
    expect(
      workspace.packageDirectories(scopes: const <String>{'api'}).single,
      endsWith('api'),
    );
    expect(
      () => workspace.packageDirectories(scopes: const <String>{'missing'}),
      throwsA(
        isA<UnknownCoverageScope>().having(
          (failure) => failure.toString(),
          'message',
          contains('missing'),
        ),
      ),
    );
  });
}

Directory _package(String name) {
  final root = _temporary();
  final package = Directory(p.join(root.path, 'packages', name))
    ..createSync(recursive: true);
  File(p.join(package.path, 'pubspec.yaml')).writeAsStringSync('name: $name');
  return package;
}

Directory _temporary() {
  final directory = Directory.systemTemp.createTempSync('workspace-coverage-');
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

void _source(Directory package, String name, String contents) {
  final file = File(p.join(package.path, 'lib', name));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

void _lcov(Directory package, String contents) {
  final file = File(p.join(package.path, 'coverage', 'lcov.info'));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}
