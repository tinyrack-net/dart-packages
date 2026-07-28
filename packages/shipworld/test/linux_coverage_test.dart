import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/linux.dart';
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

final class _RecordingExecutor implements ProcessExecutor {
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

void main() {
  test('build removes a pre-existing AppDir before staging', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'shipworld-linux-cov-',
    );
    addTearDown(() => temporary.delete(recursive: true));

    // Pre-create the AppDir with a stale file so the build exercises the
    // existing-directory cleanup branch.
    final staleAppDir = Directory(
      p.join(temporary.path, '.shipworld', 'appimage', 'example'),
    );
    await staleAppDir.create(recursive: true);
    await File(p.join(staleAppDir.path, 'stale')).writeAsString('old');

    final payload = Directory(p.join(temporary.path, 'payload'));
    await payload.create();
    await File(p.join(payload.path, 'example')).writeAsString('binary');
    final icon = File(p.join(temporary.path, 'icon.svg'));
    await icon.writeAsString('<svg/>');
    final executor = _RecordingExecutor();

    await LinuxPackagingService(ShipworldContext(process: executor)).build(
      repoRoot: temporary.path,
      payload: DirectoryPayload(
        directoryPath: payload.path,
        launcherRelativePath: 'example',
      ),
      config: AppImageConfig(
        name: 'example',
        displayName: 'Example',
        iconPath: icon.path,
        categories: const ['Utility'],
      ),
      outputPath: p.join('dist', 'Example.AppImage'),
      arch: 'x86_64',
      appImageToolPath: '/opt/appimagetool',
    );

    // The stale file must be gone after the rebuild.
    expect(await File(p.join(staleAppDir.path, 'stale')).exists(), isFalse);
    expect(
      executor.calls,
      contains(
        equals([
          '/opt/appimagetool',
          '--appimage-extract-and-run',
          staleAppDir.path,
          p.join(temporary.path, 'dist', 'Example.AppImage'),
        ]),
      ),
    );
  });
}
