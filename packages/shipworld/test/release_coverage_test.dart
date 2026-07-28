import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/release.dart';
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

/// Git client with scripted, per-invocation overrides and optional failures.
final class ScriptedGit implements GitClient {
  ScriptedGit({this.responder, this.failWhen});

  final String? Function(List<String> arguments)? responder;
  final bool Function(List<String> arguments)? failWhen;
  final calls = <List<String>>[];

  @override
  Future<String> run(
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    calls.add(List.of(arguments));
    if (failWhen?.call(arguments) == true) {
      throw const ShipworldException('injected git failure');
    }
    final override = responder?.call(arguments);
    if (override != null) return override;
    return switch (arguments) {
      ['diff', '--cached', '--name-only'] => '',
      ['status', '--porcelain'] => '',
      ['branch', '--show-current'] => 'main',
      ['tag', '--list', _] => '',
      ['ls-remote', ...] => '',
      ['rev-parse', 'HEAD'] => 'abc123',
      ['rev-parse', ...] => 'abc123',
      ['rev-list', '-n', '1', _] => 'abc123',
      _ => '',
    };
  }
}

const _defaultChangelog = '# Changelog\n\n## 0.1.2\n\n- Patch.\n';

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('shipworld-cov-');
  });

  tearDown(() async {
    if (temporary.existsSync()) {
      await temporary.delete(recursive: true);
    }
  });

  /// Builds a single-target repository and returns its loaded config.
  Future<ShipworldConfig> singleTarget({
    ShipworldTargetKind kind = ShipworldTargetKind.pubPackage,
    String version = '0.1.1',
    bool changelogInConfig = true,
    String? changelogContent = _defaultChangelog,
    String branch = 'main',
    bool synchronized = false,
    String tag = 'cliweave-v{version}',
  }) async {
    final root = p.join(temporary.path, 'packages', 'cliweave');
    await Directory(p.join(root, 'lib')).create(recursive: true);
    await File(
      p.join(root, 'pubspec.yaml'),
    ).writeAsString('name: cliweave\nversion: $version\n');
    if (changelogContent != null) {
      await File(p.join(root, 'CHANGELOG.md')).writeAsString(changelogContent);
    }
    if (synchronized) {
      await File(
        p.join(root, 'lib', 'version.g.dart'),
      ).writeAsString(renderVersionConstant('0.0.0'));
    }
    final syncBlock = synchronized
        ? '      synchronized:\n'
              '        - type: dart-constant\n'
              '          path: lib/version.g.dart\n'
        : '';
    final changelogLine = changelogInConfig
        ? '    changelog: CHANGELOG.md\n'
        : '';
    final configFile = File(p.join(temporary.path, 'shipworld.yaml'));
    await configFile.writeAsString('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  cliweave:
    kind: ${kind.yamlName}
    root: packages/cliweave
    version:
      source: pubspec.yaml
$syncBlock    tag: "$tag"
    commit: "release: cliweave {version}"
    branch: $branch
$changelogLine''');
    return loadShipworldConfig(configFile.path);
  }

  ReleaseService serviceFor(
    ShipworldConfig config, {
    ScriptedGit? git,
    Map<String, String> environment = const {},
  }) {
    return ReleaseService(
      config: config,
      context: ShipworldContext(
        git: git ?? ScriptedGit(),
        environment: environment,
      ),
    );
  }

  group('_bumpConfiguredVersion', () {
    test('applies a major bump', () async {
      final config = await singleTarget(
        changelogContent: '# Changelog\n\n## 1.0.0\n\n- Major.\n',
      );

      final result = await serviceFor(
        config,
      ).prepare(bumps: {'cliweave': ReleaseType.major}, dryRun: true);

      expect(result.targets.single.version, '1.0.0');
      expect(result.targets.single.tag, 'cliweave-v1.0.0');
    });

    test('rejects non-numeric Flutter build metadata', () async {
      final config = await singleTarget(
        kind: ShipworldTargetKind.flutterApplication,
        version: '1.2.3+abc',
      );

      await expectLater(
        serviceFor(
          config,
        ).prepare(bumps: {'cliweave': ReleaseType.patch}, dryRun: true),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('Flutter build metadata must start') &&
                (error as ShipworldException).code == 'invalid_version',
          ),
        ),
      );
    });
  });

  group('_validateChangelog', () {
    test('fails when the changelog file is missing', () async {
      final config = await singleTarget(
        changelogInConfig: true,
        changelogContent: null,
      );

      await expectLater(
        serviceFor(
          config,
        ).prepare(bumps: {'cliweave': ReleaseType.patch}, dryRun: true),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('changelog not found') &&
                (error as ShipworldException).code == 'invalid_changelog',
          ),
        ),
      );
    });

    test('fails when the changelog lacks the version heading', () async {
      final config = await singleTarget(
        changelogContent: '# Changelog\n\n## 9.9.9\n\n- Unrelated.\n',
      );

      await expectLater(
        serviceFor(
          config,
        ).prepare(bumps: {'cliweave': ReleaseType.patch}, dryRun: true),
        throwsA(
          predicate(
            (Object? error) => '$error'.contains('must contain "## 0.1.2"'),
          ),
        ),
      );
    });

    test('reads the section body bounded by the next heading', () async {
      final config = await singleTarget(
        changelogContent:
            '# Changelog\n\n## 0.1.2\n\n- New stuff.\n\n## 0.1.1\n\n- Old.\n',
      );

      final result = await serviceFor(
        config,
      ).prepare(bumps: {'cliweave': ReleaseType.patch}, dryRun: true);

      expect(result.targets.single.version, '0.1.2');
    });

    test('fails when the version section is empty', () async {
      final config = await singleTarget(
        changelogContent: '# Changelog\n\n## 0.1.2\n\n## 0.1.1\n\n- Old.\n',
      );

      await expectLater(
        serviceFor(
          config,
        ).prepare(bumps: {'cliweave': ReleaseType.patch}, dryRun: true),
        throwsA(
          predicate(
            (Object? error) => '$error'.contains('section for 0.1.2 is empty'),
          ),
        ),
      );
    });
  });

  group('prepare', () {
    test('rejects an unrelated dirty worktree', () async {
      final config = await singleTarget();
      final git = ScriptedGit(
        responder: (arguments) => switch (arguments) {
          ['status', '--porcelain'] => ' M packages/cliweave/lib/other.dart\n',
          _ => null,
        },
      );

      await expectLater(
        serviceFor(
          config,
          git: git,
        ).prepare(bumps: {'cliweave': ReleaseType.patch}),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('unrelated changes') &&
                '$error'.contains('packages/cliweave/lib/other.dart') &&
                (error as ShipworldException).code == 'dirty_worktree',
          ),
        ),
      );
    });

    test('rejects preparation from the wrong branch', () async {
      final config = await singleTarget();
      final git = ScriptedGit(
        responder: (arguments) => switch (arguments) {
          ['branch', '--show-current'] => 'feature',
          _ => null,
        },
      );

      await expectLater(
        serviceFor(
          config,
          git: git,
        ).prepare(bumps: {'cliweave': ReleaseType.patch}),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('must be prepared from main') &&
                (error as ShipworldException).code == 'wrong_branch',
          ),
        ),
      );
    });

    test('rejects a tag that already exists locally', () async {
      final config = await singleTarget();
      final git = ScriptedGit(
        responder: (arguments) => switch (arguments) {
          ['tag', '--list', 'cliweave-v0.1.2'] => 'cliweave-v0.1.2',
          _ => null,
        },
      );

      await expectLater(
        serviceFor(
          config,
          git: git,
        ).prepare(bumps: {'cliweave': ReleaseType.patch}),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('Release tag already exists') &&
                (error as ShipworldException).code == 'tag_exists',
          ),
        ),
      );
    });

    test('writes, syncs generated files, and commits on success', () async {
      final config = await singleTarget(synchronized: true);
      final git = ScriptedGit();

      final result = await serviceFor(
        config,
        git: git,
      ).prepare(bumps: {'cliweave': ReleaseType.patch});

      expect(result.dryRun, isFalse);
      expect(result.targets.single.version, '0.1.2');
      expect(result.commitMessage, 'release: cliweave 0.1.2');

      final pubspec = await File(
        p.join(temporary.path, 'packages', 'cliweave', 'pubspec.yaml'),
      ).readAsString();
      expect(pubspec, contains('version: 0.1.2'));

      final generated = await File(
        p.join(temporary.path, 'packages', 'cliweave', 'lib', 'version.g.dart'),
      ).readAsString();
      expect(generated, contains("const String packageVersion = '0.1.2';"));

      expect(git.calls.any((call) => call.first == 'commit'), isTrue);
    });
  });

  group('finalize', () {
    test('rejects finalization from the wrong branch', () async {
      final config = await singleTarget(
        changelogContent: null,
        changelogInConfig: false,
      );
      final git = ScriptedGit(
        responder: (arguments) => switch (arguments) {
          ['branch', '--show-current'] => 'feature',
          _ => null,
        },
      );

      await expectLater(
        serviceFor(config, git: git).finalize(targetNames: const ['cliweave']),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('must be finalized together from main') &&
                (error as ShipworldException).code == 'wrong_branch',
          ),
        ),
      );
    });

    test('rejects an unmerged HEAD', () async {
      final config = await singleTarget(
        changelogContent: null,
        changelogInConfig: false,
      );
      final git = ScriptedGit(
        responder: (arguments) => switch (arguments) {
          ['rev-parse', 'HEAD'] => 'local-head',
          ['rev-parse', 'refs/remotes/origin/main'] => 'remote-head',
          _ => null,
        },
      );

      await expectLater(
        serviceFor(config, git: git).finalize(targetNames: const ['cliweave']),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('HEAD must equal origin/main') &&
                (error as ShipworldException).code == 'unmerged_head',
          ),
        ),
      );
    });

    test('rejects a tag that already exists during finalize', () async {
      final config = await singleTarget(
        changelogContent: '# Changelog\n\n## 0.1.1\n\n- Current.\n',
      );
      final git = ScriptedGit(
        responder: (arguments) => switch (arguments) {
          ['tag', '--list', 'cliweave-v0.1.1'] => 'cliweave-v0.1.1',
          _ => null,
        },
      );

      await expectLater(
        serviceFor(config, git: git).finalize(targetNames: const ['cliweave']),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('Release tag already exists') &&
                (error as ShipworldException).code == 'tag_exists',
          ),
        ),
      );
    });

    test('rejects a tag that does not point at release HEAD', () async {
      final config = await singleTarget(
        changelogContent: '# Changelog\n\n## 0.1.1\n\n- Current.\n',
      );
      final git = ScriptedGit(
        responder: (arguments) => switch (arguments) {
          ['rev-list', '-n', '1', _] => 'other-head',
          _ => null,
        },
      );

      await expectLater(
        serviceFor(config, git: git).finalize(targetNames: const ['cliweave']),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('does not point to release HEAD') &&
                (error as ShipworldException).code == 'tag_target_mismatch',
          ),
        ),
      );

      expect(git.calls, contains(equals(['tag', '-d', 'cliweave-v0.1.1'])));
    });
  });

  group('verify', () {
    test('returns the expected tag when the CI ref matches', () async {
      final config = await singleTarget(
        changelogInConfig: false,
        changelogContent: null,
      );
      final service = serviceFor(
        config,
        environment: const {'GITHUB_REF_NAME': 'cliweave-v0.1.1'},
      );

      expect(await service.verify('cliweave'), 'cliweave-v0.1.1');
    });

    test('throws when the CI ref does not match', () async {
      final config = await singleTarget(
        changelogInConfig: false,
        changelogContent: null,
      );
      final service = serviceFor(
        config,
        environment: const {'GITHUB_REF_NAME': 'cliweave-v9.9.9'},
      );

      await expectLater(
        service.verify('cliweave'),
        throwsA(
          predicate(
            (Object? error) =>
                '$error'.contains('does not match cliweave version') &&
                (error as ShipworldException).code == 'tag_mismatch',
          ),
        ),
      );
    });
  });
}
