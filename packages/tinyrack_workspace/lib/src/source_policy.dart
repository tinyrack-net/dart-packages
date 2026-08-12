import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One violation of the pinned Tinyrack dependency policy.
final class TinyrackSourceViolation {
  const TinyrackSourceViolation({
    required this.path,
    required this.package,
    required this.rule,
    required this.message,
  });

  final String path;
  final String package;
  final String rule;
  final String message;

  @override
  String toString() => '$path: [$rule] $package: $message';
}

/// Verifies immutable public Git sources for Tinyrack-owned packages.
final class TinyrackSourcePolicy {
  const TinyrackSourcePolicy();

  static final RegExp _commit = RegExp(r'^[0-9a-f]{40}$');
  static const Map<String, _Source> _knownSources = <String, _Source>{
    'tinyrack_ui': _Source('design', 'packages/ui_flutter'),
    'cliweave': _Source('dart-packages', 'packages/cliweave'),
    'dartage': _Source('dart-packages', 'packages/dartage'),
    'lua_tool_runtime': _Source('dart-packages', 'packages/lua_tool_runtime'),
    'ptyworld': _Source('dart-packages', 'packages/ptyworld'),
    'shipworld': _Source('dart-packages', 'packages/shipworld'),
    'tinyrack_workspace': _Source(
      'dart-packages',
      'packages/tinyrack_workspace',
    ),
    'vtworld': _Source('dart-packages', 'packages/vtworld'),
    'dropwell': _Source('flutter-packages', 'packages/dropwell'),
    'termworld': _Source('flutter-packages', 'packages/termworld'),
  };
  static const Set<String> _ignoredDirectories = <String>{
    '.dart_tool',
    '.git',
    'build',
    'coverage',
  };

  List<TinyrackSourceViolation> verify(String rootPath) {
    final violations = <TinyrackSourceViolation>[];
    for (final entity in Directory(
      rootPath,
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is! File || _isIgnored(rootPath, entity.path)) continue;
      switch (p.basename(entity.path)) {
        case 'pubspec.yaml':
          violations.addAll(_verifyManifest(entity));
        case 'pubspec.lock':
          violations.addAll(_verifyLockfile(entity));
      }
    }
    violations.sort((left, right) {
      final byPath = left.path.compareTo(right.path);
      return byPath != 0 ? byPath : left.package.compareTo(right.package);
    });
    return List<TinyrackSourceViolation>.unmodifiable(violations);
  }

  bool _isIgnored(String rootPath, String filePath) => p
      .split(p.relative(filePath, from: rootPath))
      .any(_ignoredDirectories.contains);

  Iterable<TinyrackSourceViolation> _verifyManifest(File file) sync* {
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) return;
    for (final sectionName in const <String>[
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final section = document[sectionName];
      if (section is! YamlMap) continue;
      for (final entry in section.entries) {
        final package = entry.key;
        if (package is! String) continue;
        final expected = _knownSources[package];
        final git = _manifestGit(entry.value);
        if (expected != null && git == null) {
          yield _violation(
            file,
            package,
            'tinyrack_manifest_source',
            'must use its pinned tinyrack-net Git source, not hosted or path',
          );
          continue;
        }
        if (git == null ||
            (expected == null && !_isTinyrackRepository(git.url))) {
          continue;
        }
        yield* _verifyGit(file, package, git, expected);
      }
    }
  }

  Iterable<TinyrackSourceViolation> _verifyLockfile(File file) sync* {
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) return;
    final packages = document['packages'];
    if (packages is! YamlMap) return;
    for (final entry in packages.entries) {
      final package = entry.key;
      final packageData = entry.value;
      if (package is! String || packageData is! YamlMap) continue;
      final expected = _knownSources[package];
      final source = packageData['source'];
      final git = _lockGit(packageData['description']);
      if (expected != null && source != 'git') {
        yield _violation(
          file,
          package,
          'tinyrack_lock_source',
          'resolved from $source; expected the pinned tinyrack-net Git source',
        );
        continue;
      }
      if (source != 'git' ||
          git == null ||
          (expected == null && !_isTinyrackRepository(git.url))) {
        continue;
      }
      yield* _verifyGit(file, package, git, expected);
      if (!_commit.hasMatch(git.resolvedRef ?? '') ||
          git.resolvedRef != git.ref) {
        yield _violation(
          file,
          package,
          'tinyrack_lock_ref',
          'resolved-ref must equal the declared 40-character commit SHA',
        );
      }
    }
  }

  Iterable<TinyrackSourceViolation> _verifyGit(
    File file,
    String package,
    _GitDescription git,
    _Source? expected,
  ) sync* {
    if (!_commit.hasMatch(git.ref ?? '')) {
      yield _violation(
        file,
        package,
        'tinyrack_git_ref',
        'ref must be an immutable 40-character lowercase commit SHA',
      );
    }
    final expectedRepository = expected?.repository;
    if (expectedRepository != null && git.url != expectedRepository) {
      yield _violation(
        file,
        package,
        'tinyrack_git_repository',
        'repository must be $expectedRepository',
      );
    }
    final expectedPath = expected?.packagePath ?? 'packages/$package';
    if (git.packagePath != expectedPath) {
      yield _violation(
        file,
        package,
        'tinyrack_git_path',
        'path must be $expectedPath',
      );
    }
  }

  _GitDescription? _manifestGit(Object? dependency) {
    if (dependency is! YamlMap) return null;
    final git = dependency['git'];
    if (git is String) return _GitDescription(url: git);
    if (git is! YamlMap) return null;
    return _GitDescription(
      url: _string(git['url']),
      ref: _string(git['ref']),
      packagePath: _string(git['path']),
    );
  }

  _GitDescription? _lockGit(Object? description) {
    if (description is! YamlMap) return null;
    return _GitDescription(
      url: _string(description['url']),
      ref: _string(description['ref']),
      resolvedRef: _string(description['resolved-ref']),
      packagePath: _string(description['path']),
    );
  }

  String? _string(Object? value) => value is String ? value : null;

  bool _isTinyrackRepository(String? url) =>
      url?.startsWith('https://github.com/tinyrack-net/') ?? false;

  TinyrackSourceViolation _violation(
    File file,
    String package,
    String rule,
    String message,
  ) => TinyrackSourceViolation(
    path: file.path,
    package: package,
    rule: rule,
    message: message,
  );
}

final class _Source {
  const _Source(String repositoryName, this.packagePath)
    : repository = 'https://github.com/tinyrack-net/$repositoryName.git';

  final String repository;
  final String packagePath;
}

final class _GitDescription {
  const _GitDescription({
    this.url,
    this.ref,
    this.resolvedRef,
    this.packagePath,
  });

  final String? url;
  final String? ref;
  final String? resolvedRef;
  final String? packagePath;
}
