import 'dart:io';

/// A member of the pub workspace, with the intra-workspace packages it needs.
final class WorkspacePackage {
  const WorkspacePackage({
    required this.name,
    required this.path,
    required this.dependencies,
  });

  /// The package name, as published (`cliweave`).
  final String name;

  /// The workspace-relative directory, in POSIX form (`packages/cliweave`).
  final String path;

  /// The names of the other workspace members this package depends on.
  final Set<String> dependencies;
}

/// Which packages a change touches, and whether the change escapes the
/// per-package split entirely.
final class AffectedPackages {
  const AffectedPackages({required this.everything, required this.names});

  /// Set when a change reaches something shared, or something unrecognised.
  /// Callers treat it as "run every package".
  final bool everything;

  /// The affected members, already closed over their dependents.
  final Set<String> names;

  bool contains(String name) => everything || names.contains(name);
}

/// The root-level entries a change may touch without affecting any package.
/// Everything else that is not under a workspace member runs the whole suite,
/// so a new top-level directory fails towards more testing rather than less.
const _ignoredRootPaths = {'LICENSE'};

bool _isIgnored(String path) =>
    !path.contains('/') &&
    (_ignoredRootPaths.contains(path) || path.endsWith('.md'));

/// Reads the `workspace:` sequence out of the root pubspec.
List<String> parseWorkspaceMembers(String rootPubspec) =>
    _sequenceUnder(rootPubspec, 'workspace');

/// Reads the top-level `name:` out of a package pubspec.
String parsePackageName(String pubspec) {
  for (final line in pubspec.split('\n')) {
    if (line.startsWith('name:')) {
      return line.substring('name:'.length).trim();
    }
  }
  throw FormatException('pubspec has no top-level `name`', pubspec);
}

/// Reads the dependency names declared under `dependencies` and
/// `dev_dependencies`. Version constraints and nested keys are irrelevant
/// here: only whether one workspace member names another matters.
Set<String> parseDependencyNames(String pubspec) => {
  ..._mappingKeysUnder(pubspec, 'dependencies'),
  ..._mappingKeysUnder(pubspec, 'dev_dependencies'),
};

/// Loads the workspace graph from disk. This deliberately avoids `package:yaml`
/// so the tool runs from a bare checkout, before `dart pub get`.
List<WorkspacePackage> readWorkspace(Directory root) {
  final rootPubspec = File.fromUri(root.uri.resolve('pubspec.yaml'));
  final memberPaths = parseWorkspaceMembers(rootPubspec.readAsStringSync());

  final sources = <String, String>{};
  for (final path in memberPaths) {
    final pubspec = File.fromUri(root.uri.resolve('$path/pubspec.yaml'));
    sources[path] = pubspec.readAsStringSync();
  }

  final names = {
    for (final entry in sources.entries)
      entry.key: parsePackageName(entry.value),
  };
  final memberNames = names.values.toSet();

  return [
    for (final path in memberPaths)
      WorkspacePackage(
        name: names[path]!,
        path: path,
        dependencies: parseDependencyNames(
          sources[path]!,
        ).where(memberNames.contains).toSet(),
      ),
  ];
}

/// Maps changed files onto the packages that must be tested, including every
/// member that depends on one of them.
AffectedPackages resolveAffected(
  List<WorkspacePackage> packages,
  Iterable<String> changedPaths,
) {
  final direct = <String>{};
  var everything = false;

  for (final raw in changedPaths) {
    final path = raw.replaceAll('\\', '/').trim();
    if (path.isEmpty || _isIgnored(path)) {
      continue;
    }

    var owned = false;
    for (final package in packages) {
      if (path.startsWith('${package.path}/')) {
        direct.add(package.name);
        owned = true;
        break;
      }
    }
    if (owned) {
      continue;
    }

    // Shared tooling, workflows, lint rules, the root pubspec — and anything
    // this tool has never been taught about.
    everything = true;
  }

  return AffectedPackages(
    everything: everything,
    names: everything
        ? packages.map((package) => package.name).toSet()
        : _withDependents(packages, direct),
  );
}

/// Walks dependency edges backwards: changing `cliweave` also has to test
/// `shipworld`, which consumes it from the workspace.
Set<String> _withDependents(
  List<WorkspacePackage> packages,
  Set<String> seeds,
) {
  final affected = {...seeds};
  var changed = true;
  while (changed) {
    changed = false;
    for (final package in packages) {
      if (affected.contains(package.name)) {
        continue;
      }
      if (package.dependencies.any(affected.contains)) {
        affected.add(package.name);
        changed = true;
      }
    }
  }
  return affected;
}

/// Collects `- item` entries from the block under a top-level [key].
List<String> _sequenceUnder(String yaml, String key) => [
  for (final line in _blockUnder(yaml, key))
    if (line.trimLeft().startsWith('- ')) line.trimLeft().substring(2).trim(),
];

/// Collects the keys of the mapping under a top-level [key], ignoring anything
/// nested more deeply (`flutter:` / `  sdk: flutter`).
Set<String> _mappingKeysUnder(String yaml, String key) {
  final block = _blockUnder(yaml, key);
  final indents = block.map(_indentOf);
  if (indents.isEmpty) {
    return {};
  }
  final depth = indents.reduce((a, b) => a < b ? a : b);
  return {
    for (final line in block)
      if (_indentOf(line) == depth && line.contains(':'))
        line.substring(0, line.indexOf(':')).trim(),
  };
}

/// The indented, non-blank, non-comment lines that follow `key:` at column 0.
List<String> _blockUnder(String yaml, String key) {
  final block = <String>[];
  var inside = false;
  for (final line in yaml.split('\n')) {
    final content = line.trimRight();
    if (content.isEmpty || content.trimLeft().startsWith('#')) {
      continue;
    }
    if (_indentOf(content) == 0) {
      if (inside) {
        break;
      }
      inside = content == '$key:' || content.startsWith('$key: ');
      continue;
    }
    if (inside) {
      block.add(content);
    }
  }
  return block;
}

int _indentOf(String line) => line.length - line.trimLeft().length;
