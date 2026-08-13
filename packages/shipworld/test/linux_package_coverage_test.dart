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

LinuxPackageConfig _config({
  LinuxLauncherStyle launcherStyle = LinuxLauncherStyle.symlink,
  String prefix = '/usr/lib',
  List<String> recommends = const <String>[],
  List<String> conflicts = const <String>[],
}) => LinuxPackageConfig(
  name: 'example',
  displayName: 'Example',
  description: 'An example app',
  executableName: 'example',
  appId: 'example',
  version: '2.0.0-beta.1',
  architecture: LinuxArchitecture.arm64,
  maintainer: 'Tinyrack <dev@tinyrack.net>',
  categories: const ['Utility'],
  terminal: true,
  icons: const <LinuxIconAsset>[],
  launcherStyle: launcherStyle,
  prefix: prefix,
  recommends: recommends,
  conflicts: conflicts,
);

void main() {
  test('removes a stale staging root before staging', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-stale-');
    addTearDown(() => temporary.delete(recursive: true));
    final stale = Directory(
      p.join(temporary.path, '.shipworld', 'deb', 'example'),
    );
    await stale.create(recursive: true);
    await File(p.join(stale.path, 'stale.txt')).writeAsString('old');
    final executable = File(p.join(temporary.path, 'example'));
    await executable.writeAsString('binary');

    await LinuxPackagingService(ShipworldContext(process: _LinuxExecutor()))
        .buildPackage(
          repoRoot: temporary.path,
          payload: ExecutablePayload(
            executablePath: executable.path,
            executableName: 'example',
          ),
          config: _config(),
          format: LinuxPackageFormat.deb,
          outputPath: p.join('dist', 'example.deb'),
          nfpmToolPath: 'nfpm',
        );

    expect(File(p.join(stale.path, 'stale.txt')).existsSync(), isFalse);
    expect(File(p.join(stale.path, 'root', 'example')).existsSync(), isTrue);
  });

  test('emits a wrapper script and honours a prefix override', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-wrap-');
    addTearDown(() => temporary.delete(recursive: true));
    final executable = File(p.join(temporary.path, 'example'));
    await executable.writeAsString('binary');

    await LinuxPackagingService(ShipworldContext(process: _LinuxExecutor()))
        .buildPackage(
          repoRoot: temporary.path,
          payload: ExecutablePayload(
            executablePath: executable.path,
            executableName: 'example',
          ),
          config: _config(
            launcherStyle: LinuxLauncherStyle.wrapper,
            prefix: '/opt',
            recommends: const ['fonts-noto'],
            conflicts: const ['example-git'],
          ),
          format: LinuxPackageFormat.deb,
          outputPath: p.join('dist', 'example.deb'),
          nfpmToolPath: 'nfpm',
        );

    final workDir = p.join(temporary.path, '.shipworld', 'deb', 'example');
    final wrapper = await File(p.join(workDir, 'example')).readAsString();
    expect(wrapper, contains('exec "/opt/example/example"'));

    final manifest = jsonDecode(
      await File(p.join(workDir, 'nfpm.json')).readAsString(),
    ) as Map<String, Object?>;
    final contents = (manifest['contents']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final launcher = contents.singleWhere(
      (entry) => entry['dst'] == '/usr/bin/example',
    );
    expect(launcher.containsKey('type'), isFalse);
    expect(launcher['src'], p.join(workDir, 'example'));
    expect(manifest['arch'], 'arm64');
    // Debian only orders a pre-release below its final version with a tilde.
    expect(manifest['version'], '2.0.0~beta.1');
    expect(manifest['recommends'], ['fonts-noto']);
    expect(manifest['conflicts'], ['example-git']);
    expect(manifest.containsKey('rpm'), isFalse);
  });
}
