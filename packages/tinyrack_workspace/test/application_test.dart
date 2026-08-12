import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tinyrack_workspace/tinyrack_workspace.dart';

void main() {
  test('source-check reports success and policy failures', () async {
    final root = _temporary();
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: fixture');
    final output = <Object?>[];
    final errors = <Object?>[];

    expect(
      await runTinyrackWorkspace(
        <String>['source-check', '--root=${root.path}'],
        out: output.add,
        error: errors.add,
      ),
      0,
    );
    expect(output.single, contains('pinned'));

    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
dependencies: {cliweave: any}
''');
    expect(
      await runTinyrackWorkspace(
        <String>['source-check', '--root=${root.path}'],
        out: output.add,
        error: errors.add,
      ),
      1,
    );
    expect(errors.last.toString(), contains('tinyrack_manifest_source'));
  });

  test('coverage-check supports scopes and percentage options', () async {
    final root = _temporary();
    final package = Directory(p.join(root.path, 'packages', 'api'))
      ..createSync(recursive: true);
    File(p.join(package.path, 'pubspec.yaml')).writeAsStringSync('name: api');
    final source = File(p.join(package.path, 'lib', 'api.dart'));
    source.parent.createSync();
    source.writeAsStringSync('int answer() => 42;');
    final report = File(p.join(package.path, 'coverage', 'lcov.info'));
    report.parent.createSync();
    report.writeAsStringSync('''
SF:lib/api.dart
LF:1
LH:1
BRF:1
BRH:1
end_of_record
''');
    final output = <Object?>[];
    final errors = <Object?>[];

    expect(
      await runTinyrackWorkspace(
        <String>[
          'coverage-check',
          '--root=${root.path}',
          '--scope=api',
          '--line=100',
          '--branch=100',
        ],
        out: output.add,
        error: errors.add,
      ),
      0,
    );
    expect(output.single, contains('line=100.0%'));
    expect(errors, isEmpty);
  });

  test('coverage-merge writes a merged tracefile', () async {
    final root = _temporary();
    final first = File(p.join(root.path, 'first.info'))
      ..writeAsStringSync('SF:lib/a.dart\nDA:1,1\nend_of_record\n');
    final second = File(p.join(root.path, 'second.info'))
      ..writeAsStringSync('SF:lib/a.dart\nDA:2,1\nend_of_record\n');
    final output = File(p.join(root.path, 'merged.info'));

    expect(
      await runTinyrackWorkspace(
        <String>[
          'coverage-merge',
          '--input=${first.path}',
          '--input=${second.path}',
          '--output=${output.path}',
        ],
        out: (_) {},
        error: (message) => fail('$message'),
      ),
      0,
    );
    expect(output.readAsStringSync(), contains('LF:2'));
  });

  test(
    'invalid commands, options, scopes, and percentages return usage',
    () async {
      final errors = <Object?>[];
      Future<int> run(List<String> arguments) =>
          runTinyrackWorkspace(arguments, out: (_) {}, error: errors.add);

      expect(await run(const <String>[]), 64);
      expect(await run(const <String>['unknown']), 64);
      expect(await run(const <String>['source-check', '--scope=x']), 64);
      expect(await run(const <String>['coverage-check', '--line=nope']), 64);
      expect(await run(const <String>['coverage-check', '--branch=101']), 64);
      expect(await run(const <String>['coverage-merge']), 64);
      expect(
        await run(const <String>[
          'coverage-merge',
          '--input=missing.info',
          '--output=out.info',
        ]),
        1,
      );
      final root = _temporary();
      expect(
        await run(<String>[
          'coverage-check',
          '--root=${root.path}',
          '--scope=missing',
        ]),
        64,
      );
      expect(errors.join('\n'), contains('Usage:'));
      expect(errors.join('\n'), contains('Unknown coverage package scope'));
    },
  );
}

Directory _temporary() {
  final directory = Directory.systemTemp.createTempSync('workspace-app-');
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}
