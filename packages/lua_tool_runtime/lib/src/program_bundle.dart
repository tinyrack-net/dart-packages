import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// An immutable, already-validated Lua program revision.
///
/// A bundle is deliberately detached from the filesystem before execution.
/// Lua can only load the modules and Markdown assets present in this snapshot.
final class LuaProgramBundle {
  /// Creates an immutable program bundle.
  factory LuaProgramBundle({
    required String revision,
    required String entrypoint,
    required Map<String, String> modules,
    List<String> preloadModules = const [],
    Map<String, String> markdownAssets = const {},
  }) {
    if (revision.trim().isEmpty || revision.contains('\u0000')) {
      throw const FormatException('Bundle revision must be non-empty.');
    }
    _validateModuleName(entrypoint, label: 'entrypoint');
    if (modules.isEmpty) {
      throw const FormatException('A Lua bundle must contain a module.');
    }
    final copiedModules = <String, String>{};
    for (final entry in modules.entries) {
      _validateModuleName(entry.key, label: 'module');
      copiedModules[entry.key] = entry.value;
    }
    if (!copiedModules.containsKey(entrypoint)) {
      throw FormatException('Entrypoint module is missing: $entrypoint');
    }
    final copiedPreloads = <String>[];
    for (final module in preloadModules) {
      _validateModuleName(module, label: 'preload module');
      if (!copiedModules.containsKey(module)) {
        throw FormatException('Preload module is missing: $module');
      }
      if (copiedPreloads.contains(module)) {
        throw FormatException('Duplicate preload module: $module');
      }
      copiedPreloads.add(module);
    }
    final copiedAssets = <String, String>{};
    for (final entry in markdownAssets.entries) {
      _validateAssetPath(entry.key);
      copiedAssets[entry.key] = entry.value;
    }
    final sortedModules = Map<String, String>.fromEntries(
      copiedModules.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
    final sortedAssets = Map<String, String>.fromEntries(
      copiedAssets.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
    return LuaProgramBundle._(
      revision: revision,
      entrypoint: entrypoint,
      modules: Map.unmodifiable(sortedModules),
      preloadModules: List.unmodifiable(copiedPreloads),
      markdownAssets: Map.unmodifiable(sortedAssets),
    );
  }

  const LuaProgramBundle._({
    required this.revision,
    required this.entrypoint,
    required this.modules,
    required this.preloadModules,
    required this.markdownAssets,
  });

  /// Consumer-supplied immutable revision identifier.
  final String revision;

  /// Module whose returned table contains named handlers.
  final String entrypoint;

  /// Safe `require` module map, keyed by dotted Lua module name.
  final Map<String, String> modules;

  /// Ordered modules loaded for side effects before the entrypoint.
  ///
  /// Preloads execute inside the same fresh safe VM and can install a public
  /// SDK table such as `tinest`, but cannot load anything outside [modules].
  final List<String> preloadModules;

  /// UTF-8 Markdown assets, keyed by normalized relative path.
  final Map<String, String> markdownAssets;

  /// Exact content identity used to detect revision collisions.
  String get contentIdentity => jsonEncode({
    'entrypoint': entrypoint,
    'modules': modules,
    'preload_modules': preloadModules,
    'markdown_assets': markdownAssets,
  });

  /// Total UTF-8 payload size sent to a native worker.
  int get encodedByteLength => utf8.encode(contentIdentity).length;
}

/// Loads a filesystem plugin snapshot into an immutable [LuaProgramBundle].
///
/// Only `main.lua`, `lua/**/*.lua`, and `prompts/**/*.md` are read. Links,
/// junctions, path escapes, unsupported files within source directories, and
/// duplicate module names are rejected before any source reaches Lua.
abstract final class LuaProgramBundleLoader {
  /// Loads one validated bundle rooted at [root].
  static Future<LuaProgramBundle> load({
    required String root,
    required String revision,
    List<String> preloadModules = const [],
  }) async {
    final rootType = await FileSystemEntity.type(root, followLinks: false);
    if (rootType != FileSystemEntityType.directory) {
      throw LuaBundleException('Bundle root is not a real directory: $root');
    }
    final rootDirectory = Directory(root).absolute;
    final resolvedRoot = await rootDirectory.resolveSymbolicLinks();
    final modules = <String, String>{};
    final assets = <String, String>{};

    final entrypoint = File(p.join(rootDirectory.path, 'main.lua'));
    if (!await entrypoint.exists()) {
      throw const LuaBundleException('Bundle is missing main.lua.');
    }
    await _rejectLinkOrEscape(entrypoint, resolvedRoot);
    modules['main'] = await entrypoint.readAsString();

    final luaDirectory = Directory(p.join(rootDirectory.path, 'lua'));
    if (await luaDirectory.exists()) {
      await _readTree(
        directory: luaDirectory,
        resolvedRoot: resolvedRoot,
        onFile: (file, relative) async {
          if (p.extension(relative) != '.lua') {
            throw LuaBundleException(
              'Unsupported file in Lua module directory: $relative',
            );
          }
          final withoutExtension = p.withoutExtension(relative);
          final module = p.split(withoutExtension).join('.');
          _validateModuleName(module, label: 'module');
          if (modules.containsKey(module)) {
            throw LuaBundleException('Duplicate Lua module: $module');
          }
          modules[module] = await file.readAsString();
        },
      );
    }

    final promptsDirectory = Directory(p.join(rootDirectory.path, 'prompts'));
    if (await promptsDirectory.exists()) {
      await _readTree(
        directory: promptsDirectory,
        resolvedRoot: resolvedRoot,
        onFile: (file, relative) async {
          if (p.extension(relative) != '.md') {
            throw LuaBundleException(
              'Unsupported file in Markdown asset directory: $relative',
            );
          }
          final assetPath = p.posix.joinAll(['prompts', ...p.split(relative)]);
          _validateAssetPath(assetPath);
          if (assets.containsKey(assetPath)) {
            throw LuaBundleException('Duplicate Markdown asset: $assetPath');
          }
          assets[assetPath] = await file.readAsString();
        },
      );
    }

    return LuaProgramBundle(
      revision: revision,
      entrypoint: 'main',
      modules: modules,
      preloadModules: preloadModules,
      markdownAssets: assets,
    );
  }

  static Future<void> _readTree({
    required Directory directory,
    required String resolvedRoot,
    required Future<void> Function(File file, String relative) onFile,
  }) async {
    await _rejectLinkOrEscape(directory, resolvedRoot);
    final entities =
        await directory.list(recursive: true, followLinks: false).toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    for (final entity in entities) {
      await _rejectLinkOrEscape(entity, resolvedRoot);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) continue;
      if (type != FileSystemEntityType.file) {
        throw LuaBundleException('Unsupported bundle entry: ${entity.path}');
      }
      await onFile(
        File(entity.path),
        p.relative(entity.path, from: directory.path),
      );
    }
  }

  static Future<void> _rejectLinkOrEscape(
    FileSystemEntity entity,
    String resolvedRoot,
  ) async {
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw LuaBundleException(
        'Links are not allowed in bundles: ${entity.path}',
      );
    }
    final resolved = await entity.resolveSymbolicLinks();
    if (resolved != resolvedRoot && !p.isWithin(resolvedRoot, resolved)) {
      throw LuaBundleException('Bundle path escapes its root: ${entity.path}');
    }
  }
}

/// A filesystem bundle could not be snapshotted safely.
final class LuaBundleException implements Exception {
  /// Creates a bundle validation failure.
  const LuaBundleException(this.message);

  /// Human-readable validation failure.
  final String message;

  @override
  String toString() => 'LuaBundleException: $message';
}

void _validateModuleName(String value, {required String label}) {
  final valid = RegExp(r'^[a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)*$');
  if (!valid.hasMatch(value)) {
    throw FormatException('Invalid Lua $label name: $value');
  }
}

void _validateAssetPath(String value) {
  if (value.isEmpty ||
      value.contains('\\') ||
      value.contains('\u0000') ||
      value.startsWith('/') ||
      !value.endsWith('.md')) {
    throw FormatException('Invalid Markdown asset path: $value');
  }
  final segments = value.split('/');
  if (segments.any(
    (segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    throw FormatException('Invalid Markdown asset path: $value');
  }
}
