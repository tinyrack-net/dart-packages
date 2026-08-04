import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/linux.dart';
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

final class _LinuxExecutor implements ProcessExecutor {
  final calls = <List<String>>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls.add([executable, ...arguments]);
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<int> runInherited(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    throw UnimplementedError();
  }
}

Future<Directory> _payloadTree(Directory root) async {
  final payload = Directory(p.join(root.path, 'payload'));
  await Directory(p.join(payload.path, 'lib')).create(recursive: true);
  await File(p.join(payload.path, 'example')).writeAsString('binary');
  await File(p.join(payload.path, 'lib', 'libflutter.so')).writeAsString('so');
  return payload;
}

LinuxPackageConfig _config({
  LinuxArchitecture architecture = LinuxArchitecture.amd64,
  String? license,
  List<LinuxIconAsset> icons = const <LinuxIconAsset>[],
  LinuxLauncherStyle launcherStyle = LinuxLauncherStyle.symlink,
  String prefix = '/usr/lib',
  String? vendor,
  String? group,
  List<String> depends = const <String>[],
  String description = 'An example app',
}) => LinuxPackageConfig(
  name: 'example',
  displayName: 'Example',
  description: description,
  executableName: 'example',
  appId: 'net.example.app',
  version: '1.2.3',
  architecture: architecture,
  maintainer: 'Tinyrack <dev@tinyrack.net>',
  categories: const ['Development'],
  terminal: false,
  icons: icons,
  license: license,
  launcherStyle: launcherStyle,
  prefix: prefix,
  vendor: vendor,
  group: group,
  depends: depends,
  homepage: 'https://example.test',
);

Future<Map<String, Object?>> _build(
  Directory temporary,
  _LinuxExecutor executor, {
  required LinuxPackageFormat format,
  required LinuxPackageConfig config,
}) async {
  final payload = await _payloadTree(temporary);
  await LinuxPackagingService(ShipworldContext(process: executor)).buildPackage(
    repoRoot: temporary.path,
    payload: DirectoryPayload(
      directoryPath: payload.path,
      launcherRelativePath: 'example',
    ),
    config: config,
    format: format,
    outputPath: p.join('dist', 'example.${format.packagerName}'),
    nfpmToolPath: '/opt/nfpm',
  );
  final manifest = File(
    p.join(
      temporary.path,
      '.shipworld',
      format.packagerName,
      'example',
      'nfpm.json',
    ),
  );
  return jsonDecode(await manifest.readAsString()) as Map<String, Object?>;
}

void main() {
  test('stages a deb tree and invokes nfpm with the deb packager', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-deb-');
    addTearDown(() => temporary.delete(recursive: true));
    final executor = _LinuxExecutor();

    final manifest = await _build(
      temporary,
      executor,
      format: LinuxPackageFormat.deb,
      config: _config(depends: const ['libgtk-3-0t64']),
    );

    expect(
      executor.calls,
      contains(
        equals([
          '/opt/nfpm',
          'package',
          '--config',
          p.join(temporary.path, '.shipworld', 'deb', 'example', 'nfpm.json'),
          '--packager',
          'deb',
          '--target',
          p.join(temporary.path, 'dist', 'example.deb'),
        ]),
      ),
    );
    expect(manifest['name'], 'example');
    expect(manifest['version'], '1.2.3');
    expect(manifest['arch'], 'amd64');
    expect(manifest['section'], 'utils');
    expect(manifest['priority'], 'optional');
    expect(manifest['maintainer'], 'Tinyrack <dev@tinyrack.net>');
    expect(manifest['homepage'], 'https://example.test');
    expect(manifest['depends'], ['libgtk-3-0t64']);
    expect(manifest.containsKey('vendor'), isFalse);
  });

  test('renders rpm-only metadata and requires a license', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-rpm-');
    addTearDown(() => temporary.delete(recursive: true));

    final manifest = await _build(
      temporary,
      _LinuxExecutor(),
      format: LinuxPackageFormat.rpm,
      config: _config(
        license: 'Apache-2.0',
        group: 'Applications/Productivity',
        vendor: 'Tinyrack',
        depends: const ['gtk3'],
      ),
    );

    expect(manifest['license'], 'Apache-2.0');
    expect(manifest['release'], '1');
    expect(manifest['vendor'], 'Tinyrack');
    expect(manifest['depends'], ['gtk3']);
    expect(
      (manifest['rpm']! as Map<String, Object?>)['group'],
      'Applications/Productivity',
    );

    await expectLater(
      _build(
        temporary,
        _LinuxExecutor(),
        format: LinuxPackageFormat.rpm,
        config: _config(),
      ),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'invalid_config',
        ),
      ),
    );
  });

  test('declares the launcher link and file modes as metadata', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-mode-');
    addTearDown(() => temporary.delete(recursive: true));

    final manifest = await _build(
      temporary,
      _LinuxExecutor(),
      format: LinuxPackageFormat.deb,
      config: _config(),
    );
    final contents = (manifest['contents']! as List<Object?>)
        .cast<Map<String, Object?>>();

    final link = contents.singleWhere(
      (entry) => entry['dst'] == '/usr/bin/example',
    );
    expect(link['type'], 'symlink');
    expect(link['src'], '/usr/lib/example/example');
    // Nothing is linked on disk, so staging behaves the same on every host.
    expect(
      Link(
        p.join(temporary.path, '.shipworld', 'deb', 'example', 'usr'),
      ).existsSync(),
      isFalse,
    );

    int modeOf(String destination) =>
        ((contents.singleWhere(
                  (entry) => entry['dst'] == destination,
                )['file_info']!
                as Map<String, Object?>)['mode']!
            as int);
    expect(modeOf('/usr/lib/example/example'), 493);
    expect(modeOf('/usr/lib/example/lib/libflutter.so'), 420);
    expect(modeOf('/usr/share/applications/net.example.app.desktop'), 420);
  });

  test('installs icons and a desktop entry that execs the link', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-icon-');
    addTearDown(() => temporary.delete(recursive: true));
    final png = File(p.join(temporary.path, 'icon-256.png'));
    await png.writeAsString('png');
    final svg = File(p.join(temporary.path, 'icon.svg'));
    await svg.writeAsString('<svg/>');

    final manifest = await _build(
      temporary,
      _LinuxExecutor(),
      format: LinuxPackageFormat.deb,
      config: _config(
        icons: <LinuxIconAsset>[
          LinuxIconAsset(size: 256, sourcePath: png.path),
          LinuxIconAsset(size: 0, sourcePath: svg.path),
        ],
      ),
    );
    final contents = (manifest['contents']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final destinations = contents.map((entry) => entry['dst']).toList();

    expect(
      destinations,
      containsAll(<String>[
        '/usr/share/icons/hicolor/256x256/apps/net.example.app.png',
        '/usr/share/icons/hicolor/scalable/apps/net.example.app.svg',
      ]),
    );
    final desktop = await File(
      p.join(
        temporary.path,
        '.shipworld',
        'deb',
        'example',
        'net.example.app.desktop',
      ),
    ).readAsString();
    expect(desktop, contains('Exec=/usr/bin/example %U'));
    expect(desktop, contains('Icon=net.example.app'));
    expect(desktop, contains('Terminal=false'));
  });

  test('maps architecture and format aliases and rejects unknown ones', () {
    expect(LinuxArchitecture.parse('x64'), LinuxArchitecture.amd64);
    expect(LinuxArchitecture.parse('x86_64'), LinuxArchitecture.amd64);
    expect(LinuxArchitecture.parse('amd64'), LinuxArchitecture.amd64);
    expect(LinuxArchitecture.parse('aarch64'), LinuxArchitecture.arm64);
    expect(LinuxArchitecture.parse('arm64'), LinuxArchitecture.arm64);
    expect(
      () => LinuxArchitecture.parse('riscv64'),
      throwsA(isA<ShipworldException>()),
    );
    expect(LinuxPackageFormat.parse('deb'), LinuxPackageFormat.deb);
    expect(LinuxPackageFormat.parse('rpm'), LinuxPackageFormat.rpm);
    expect(
      () => LinuxPackageFormat.parse('apk'),
      throwsA(isA<ShipworldException>()),
    );
  });

  test('escapes metadata that would otherwise break the manifest', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-esc-');
    addTearDown(() => temporary.delete(recursive: true));

    final manifest = await _build(
      temporary,
      _LinuxExecutor(),
      format: LinuxPackageFormat.deb,
      config: _config(description: 'Quote " and\nnewline'),
    );

    expect(manifest['description'], 'Quote " and\nnewline');
  });
}
