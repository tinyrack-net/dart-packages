import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

/// Writes [yaml] to a fresh temp `shipworld.yaml` and returns its path.
Future<String> writeConfig(String yaml) async {
  final dir = await Directory.systemTemp.createTemp('shipworld-cov-');
  addTearDown(() => dir.delete(recursive: true));
  final file = File(p.join(dir.path, 'shipworld.yaml'));
  await file.writeAsString(yaml);
  return file.path;
}

Matcher throwsCode(String code) => throwsA(
  isA<ShipworldException>().having((error) => error.code, 'code', code),
);

void main() {
  test(
    'parses synchronized version writers and resolves their paths',
    () async {
      final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version:
      source: pubspec.yaml
      synchronized:
        - type: dart-constant
          path: lib/version.dart
          constant: appVersion
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

      final config = await loadShipworldConfig(path);
      final target = config.target('app');
      expect(target.version.synchronized, hasLength(1));
      final writer = target.version.synchronized.single;
      expect(writer.kind, VersionWriterKind.dartConstant);
      expect(writer.path, p.join('lib', 'version.dart'));
      expect(writer.constant, 'appVersion');
      expect(
        config.renderBatchCommit([(name: 'app', version: '1.0.0')]),
        'release: app 1.0.0',
      );
    },
  );

  test('target() throws for unknown target names', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

    final config = await loadShipworldConfig(path);
    expect(() => config.target('missing'), throwsCode('unknown_target'));
  });

  test('rejects unknown target kinds', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: bogus-kind
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects unknown synchronized writer types', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version:
      source: pubspec.yaml
      synchronized:
        - type: bogus-writer
          path: lib/version.dart
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects unknown payload kinds', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: flutter-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
    payload:
      kind: bogus-payload
      launcher: run.sh
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects non-map version sections', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version: not-a-map
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects empty required strings', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: ""
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects empty optional strings', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version:
      source: pubspec.yaml
    changelog: ""
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects non-boolean linux terminal flags', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: flutter-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
    linux:
      icon: icon.png
      categories:
        - Utility
      terminal: not-a-bool
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects linux icons that escape the repository', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: flutter-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
    linux:
      icon: ../../escape.png
      categories:
        - Utility
      terminal: true
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_path'));
  });

  test('rejects non-list category values', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: flutter-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
    linux:
      icon: icon.png
      categories: not-a-list
      terminal: true
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects empty category entries', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: flutter-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
    linux:
      icon: icon.png
      categories:
        - ""
      terminal: true
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects non-list synchronized sections', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version:
      source: pubspec.yaml
      synchronized: not-a-list
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects non-MSIX windows application ids', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: flutter-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
    windows:
      application-id: "1invalid"
      executable: app.exe
      identity:
        name-env: NAME
        publisher-env: PUBLISHER
        publisher-display-name-env: PUBLISHER_DISPLAY
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects missing config files', () async {
    final dir = await Directory.systemTemp.createTemp('shipworld-cov-');
    addTearDown(() => dir.delete(recursive: true));
    final missing = p.join(dir.path, 'does-not-exist.yaml');

    await expectLater(
      loadShipworldConfig(missing),
      throwsCode('config_not_found'),
    );
  });

  test('rejects malformed YAML documents', () async {
    final path = await writeConfig('remote: "unterminated\n');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  test('rejects tag templates without the version placeholder', () async {
    final path = await writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-release"
    commit: "release: app {version}"
    branch: main
''');

    await expectLater(loadShipworldConfig(path), throwsCode('invalid_config'));
  });

  group('homebrew platforms', () {
    Future<String> configWith(String platforms) => writeConfig('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  app:
    kind: cli-application
    root: app
    version:
      source: pubspec.yaml
    tag: "app-v{version}"
    commit: "release: app {version}"
    branch: main
    product:
      name: app
      display-name: App
      description: An app
      executable: app
      homepage: https://example.com
      repository: example/app
    homebrew:
      formula-class: App
      artifact-prefix: app
$platforms
''');

    test('defaults to every platform when omitted', () async {
      final config = await loadShipworldConfig(await configWith(''));

      expect(config.target('app').homebrew?.platforms, <String>[
        'macos-arm64',
        'macos-x64',
        'linux-arm64',
        'linux-x64',
      ]);
    });

    test('keeps the declared Formula order, not the listed one', () async {
      // Two configs naming the same platforms must render byte-identical
      // Formulae, so the caller's ordering is discarded.
      final config = await loadShipworldConfig(
        await configWith('''
      platforms:
        - linux-x64
        - macos-arm64'''),
      );

      expect(config.target('app').homebrew?.platforms, <String>[
        'macos-arm64',
        'linux-x64',
      ]);
    });

    test('rejects an unknown platform', () async {
      final path = await configWith('''
      platforms:
        - linux-riscv''');

      await expectLater(
        loadShipworldConfig(path),
        throwsCode('invalid_config'),
      );
    });

    test('rejects an empty platform list', () async {
      final path = await configWith('''
      platforms: []''');

      await expectLater(
        loadShipworldConfig(path),
        throwsCode('invalid_config'),
      );
    });
  });
}
