import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tinyrack_workspace/tinyrack_workspace.dart';

void main() {
  const policy = TinyrackSourcePolicy();

  test('rejects hosted sources in manifests and lockfiles', () {
    final root = _temporary();
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
dependencies:
  tinyrack_ui: ^1.0.0
''');
    File(p.join(root.path, 'pubspec.lock')).writeAsStringSync('''
packages:
  cliweave:
    dependency: transitive
    description: {name: cliweave, url: https://pub.dev}
    source: hosted
    version: 1.0.0
''');

    expect(
      policy.verify(root.path).map((violation) => violation.rule),
      containsAll(<String>['tinyrack_manifest_source', 'tinyrack_lock_source']),
    );
  });

  test('rejects movable refs, wrong repositories and paths', () {
    final root = _temporary();
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
dependencies:
  termworld:
    git:
      url: https://github.com/tinyrack-net/dart-packages.git
      ref: main
      path: packages/not_termworld
''');

    expect(
      policy.verify(root.path).map((violation) => violation.rule),
      containsAll(<String>[
        'tinyrack_git_repository',
        'tinyrack_git_ref',
        'tinyrack_git_path',
      ]),
    );
  });

  test('rejects a lockfile resolved ref that differs from its commit', () {
    final root = _temporary();
    File(p.join(root.path, 'pubspec.lock')).writeAsStringSync('''
packages:
  lua_tool_runtime:
    dependency: direct main
    description:
      path: packages/lua_tool_runtime
      ref: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      resolved-ref: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
      url: https://github.com/tinyrack-net/dart-packages.git
    source: git
    version: 0.2.0
''');

    expect(
      policy.verify(root.path).map((violation) => violation.rule),
      contains('tinyrack_lock_ref'),
    );
  });

  test('accepts exact pins and ignores generated directories', () {
    final root = _temporary();
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
dependencies:
  tinyrack_workspace:
    git:
      url: https://github.com/tinyrack-net/dart-packages.git
      ref: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      path: packages/tinyrack_workspace
''');
    File(p.join(root.path, 'pubspec.lock')).writeAsStringSync('''
packages:
  tinyrack_workspace:
    dependency: direct main
    description:
      path: packages/tinyrack_workspace
      ref: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      resolved-ref: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      url: https://github.com/tinyrack-net/dart-packages.git
    source: git
    version: 0.1.0
''');
    final build = Directory(p.join(root.path, 'build'))..createSync();
    File(p.join(build.path, 'pubspec.yaml')).writeAsStringSync('''
name: ignored
dependencies: {dartage: any}
''');

    expect(policy.verify(root.path), isEmpty);
  });

  test('checks unknown Tinyrack repositories using conventional paths', () {
    final root = _temporary();
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
dependencies:
  future_package:
    git:
      url: https://github.com/tinyrack-net/future.git
      ref: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      path: packages/wrong
''');

    final violation = policy.verify(root.path).single;
    expect(violation.rule, 'tinyrack_git_path');
    expect(violation.toString(), contains('future_package'));
  });
}

Directory _temporary() {
  final directory = Directory.systemTemp.createTempSync('workspace-source-');
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}
