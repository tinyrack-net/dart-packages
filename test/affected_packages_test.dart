import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/affected.dart';

const _packages = [
  WorkspacePackage(
    name: 'cliweave',
    path: 'packages/cliweave',
    dependencies: {},
  ),
  WorkspacePackage(name: 'dartage', path: 'packages/dartage', dependencies: {}),
  WorkspacePackage(
    name: 'lua_tool_runtime',
    path: 'packages/lua_tool_runtime',
    dependencies: {},
  ),
  WorkspacePackage(
    name: 'ptyworld',
    path: 'packages/ptyworld',
    dependencies: {},
  ),
  WorkspacePackage(
    name: 'shipworld',
    path: 'packages/shipworld',
    dependencies: {'cliweave'},
  ),
];

Set<String> _affected(List<String> paths) {
  final affected = resolveAffected(_packages, paths);
  return {
    for (final package in _packages)
      if (affected.contains(package.name)) package.name,
  };
}

void main() {
  test('limits a leaf package change to that package', () {
    expect(_affected(['packages/ptyworld/lib/src/pty_process.dart']), {
      'ptyworld',
    });
  });

  test('pulls in dependents of a changed package', () {
    expect(_affected(['packages/cliweave/lib/cliweave.dart']), {
      'cliweave',
      'shipworld',
    });
  });

  test('does not pull in dependencies of a changed package', () {
    expect(_affected(['packages/shipworld/lib/src/application.dart']), {
      'shipworld',
    });
  });

  test('treats shared tooling as a change to everything', () {
    for (final path in [
      'pubspec.yaml',
      'analysis_options.yaml',
      'tool/verify_coverage.dart',
      'test/lcov_test.dart',
      '.github/workflows/ci.yml',
    ]) {
      final affected = resolveAffected(_packages, [path]);
      expect(affected.everything, isTrue, reason: path);
      expect(affected.names.length, _packages.length, reason: path);
    }
  });

  test('treats an unrecognised path as a change to everything', () {
    // The safe default: a directory this tool has never seen runs the full
    // suite rather than silently exempting itself from CI.
    final affected = resolveAffected(_packages, ['docs/design/pty.md']);

    expect(affected.everything, isTrue);
  });

  test('ignores root documentation and licensing', () {
    final affected = resolveAffected(_packages, [
      'README.md',
      'AGENTS.md',
      'LICENSE',
      '',
    ]);

    expect(affected.everything, isFalse);
    expect(affected.names, isEmpty);
  });

  test('keeps package documentation with its package', () {
    // A package README ships to pub.dev, so it is not root documentation.
    expect(_affected(['packages/dartage/README.md']), {'dartage'});
  });

  test('accepts the Windows path separator git can report', () {
    expect(_affected([r'packages\ptyworld\lib\ptyworld.dart']), {'ptyworld'});
  });

  test('reads the real workspace graph from the pubspecs', () {
    final root = Directory.current;
    final packages = readWorkspace(root);

    expect(packages.map((package) => package.name), [
      'cliweave',
      'dartage',
      'lua_tool_runtime',
      'ptyworld',
      'shipworld',
    ]);
    // The one intra-workspace edge in this repository. If a second appears,
    // the reverse closure above starts doing more work on its own.
    expect(
      {
        for (final package in packages)
          if (package.dependencies.isNotEmpty)
            package.name: package.dependencies,
      },
      {
        'shipworld': {'cliweave'},
      },
    );
  });

  test(
    'parses workspace members and dependency names without a YAML parser',
    () {
      const pubspec = '''
name: example
# A comment, and a blank line, inside the file.

environment:
  sdk: ^3.12.2

workspace:
  - packages/one
  - packages/two

dependencies:
  cliweave: ^0.2.0
  flutter:
    sdk: flutter

dev_dependencies:
  test: ^1.26.0
''';

      expect(parsePackageName(pubspec), 'example');
      expect(parseWorkspaceMembers(pubspec), ['packages/one', 'packages/two']);
      expect(parseDependencyNames(pubspec), {'cliweave', 'flutter', 'test'});
    },
  );
}
