import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

void main() {
  test('loads independently versioned package targets', () async {
    final config = await loadShipworldConfig(
      p.join('example', 'multi_package', 'shipworld.yaml'),
    );

    expect(config.targets.keys, ['cliweave', 'dartage']);
    expect(config.target('cliweave').kind, ShipworldTargetKind.pubPackage);
    expect(config.target('dartage').renderTag('0.2.0'), 'dartage-v0.2.0');
  });

  test('rejects unknown schema versions', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-config-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final file = File(p.join(temporary.path, 'shipworld.yaml'));
    await file.writeAsString(
      'schema: 2\nremote: origin\n'
      'batch-commit: "release: {targets}"\ntargets: {}\n',
    );

    await expectLater(
      loadShipworldConfig(file.path),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'unsupported_schema',
        ),
      ),
    );

    await file.writeAsString('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  bad:
    kind: pub-package
    root: ../outside
    version:
      source: pubspec.yaml
    tag: "bad-v{version}"
    commit: "release: bad {version}"
    branch: main
''');
    await expectLater(
      loadShipworldConfig(file.path),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'invalid_path',
        ),
      ),
    );
  });

  test('parses typed Flutter desktop packaging sections', () async {
    final config = await loadShipworldConfig(
      p.join('test', 'fixtures', 'flutter_app', 'shipworld.yaml'),
    );
    final target = config.target('fixture');

    expect(target.kind, ShipworldTargetKind.flutterApplication);
    expect(target.payload?.kind, PayloadKind.directory);
    expect(target.windows?.identityEnvironment.name, 'SHIPWORLD_MSIX_NAME');
    expect(target.macos?.entitlements, 'entitlements.plist');
    expect(target.linux?.categories, ['Utility']);
    expect(target.homebrew?.formulaClass, 'ShipworldFixture');
  });

  test('rejects unknown fields and escaping target roots', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-config-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final file = File(p.join(temporary.path, 'shipworld.yaml'));
    await file.writeAsString('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
unexpected: true
targets:
  bad:
    kind: pub-package
    root: ../outside
    version:
      source: pubspec.yaml
    tag: "bad-v{version}"
    commit: "release: bad {version}"
    branch: main
''');

    await expectLater(
      loadShipworldConfig(file.path),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'invalid_config',
        ),
      ),
    );
  });

  test('parses Linux distribution packaging fields', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-linux-config-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    await File(p.join(temporary.path, 'pubspec.yaml'))
        .writeAsString('name: example\nversion: 1.0.0\n');
    final file = File(p.join(temporary.path, 'shipworld.yaml'));
    await file.writeAsString('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  example:
    kind: flutter-application
    root: .
    version:
      source: pubspec.yaml
    tag: "v{version}"
    commit: "release: v{version}"
    branch: main
    linux:
      icon: icon.svg
      categories: [Development]
      terminal: false
      maintainer: "Tinyrack <dev@tinyrack.net>"
      license: Apache-2.0
      app-id: net.example.app
      launcher-style: wrapper
      icons:
        - { size: 256, path: icon-256.png }
      deb:
        depends: [libgtk-3-0t64]
        section: devel
      rpm:
        requires: [gtk3]
        release: "2"
        group: Applications/Productivity
    macos:
      bundle-name: Example
      bundle-id: net.example.app
      minimum-version: ventura
''');

    final linux = (await loadShipworldConfig(file.path))
        .target('example')
        .linux;
    expect(linux?.maintainer, 'Tinyrack <dev@tinyrack.net>');
    expect(linux?.license, 'Apache-2.0');
    expect(linux?.appId, 'net.example.app');
    expect(linux?.launcherStyle, 'wrapper');
    expect(linux?.icons.single.size, 256);
    expect(linux?.deb.depends, ['libgtk-3-0t64']);
    expect(linux?.deb.section, 'devel');
    expect(linux?.rpm.requires, ['gtk3']);
    expect(linux?.rpm.release, '2');

    final macos = (await loadShipworldConfig(file.path))
        .target('example')
        .macos;
    expect(macos?.bundleName, 'Example');
    expect(macos?.minimumVersion, 'ventura');
  });

  test('keeps accepting a Linux block that only sets the AppImage keys', () async {
    // proxer and dotweave ship exactly these three keys and must keep loading.
    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-linux-legacy-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    await File(p.join(temporary.path, 'pubspec.yaml'))
        .writeAsString('name: example\nversion: 1.0.0\n');
    final file = File(p.join(temporary.path, 'shipworld.yaml'));
    await file.writeAsString('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  example:
    kind: cli-application
    root: .
    version:
      source: pubspec.yaml
    tag: "v{version}"
    commit: "release: v{version}"
    branch: main
    linux:
      icon: icon.svg
      categories: [Utility]
      terminal: true
''');

    final linux = (await loadShipworldConfig(file.path))
        .target('example')
        .linux;
    expect(linux?.icon, 'icon.svg');
    expect(linux?.terminal, isTrue);
    expect(linux?.maintainer, isNull);
    expect(linux?.icons, isEmpty);
    expect(linux?.deb.section, 'utils');
    expect(linux?.rpm.release, '1');
    expect(linux?.launcherStyle, 'symlink');
  });

  test('rejects malformed Linux packaging values', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-linux-bad-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    await File(p.join(temporary.path, 'pubspec.yaml'))
        .writeAsString('name: example\nversion: 1.0.0\n');
    final file = File(p.join(temporary.path, 'shipworld.yaml'));

    Future<void> expectRejected(String linuxBlock) async {
      await file.writeAsString('''
schema: 1
remote: origin
batch-commit: "release: {targets}"
targets:
  example:
    kind: flutter-application
    root: .
    version:
      source: pubspec.yaml
    tag: "v{version}"
    commit: "release: v{version}"
    branch: main
    linux:
      icon: icon.svg
      categories: [Development]
      terminal: false
$linuxBlock
''');
      await expectLater(
        loadShipworldConfig(file.path),
        throwsA(
          isA<ShipworldException>().having(
            (error) => error.code,
            'code',
            'invalid_config',
          ),
        ),
      );
    }

    await expectRejected('      launcher-style: hardlink');
    await expectRejected('      icons: not-a-list');
    await expectRejected('      icons:\n        - { size: -1, path: a.png }');
    await expectRejected('      deb: { unexpected: true }');
    await expectRejected('      rpm: { unexpected: true }');
  });

  test('ships a valid JSON Schema document', () async {
    final schema = jsonDecode(
      await File(p.join('schema', 'shipworld.schema.json')).readAsString(),
    ) as Map<String, Object?>;

    expect(schema['title'], 'Shipworld configuration');
    expect(schema[r'$defs'], isA<Map<String, Object?>>());
  });
}
