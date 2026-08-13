import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

/// Attempts to create a symlink, returning false when the platform refuses
/// (for example, Windows without the required privilege).
Future<bool> _symlinksSupported(String directory) async {
  final target = File(p.join(directory, '.probe-target'));
  await target.writeAsString('probe');
  final link = Link(p.join(directory, '.probe-link'));
  try {
    await link.create(target.path);
    return true;
  } on FileSystemException {
    return false;
  }
}

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('shipworld-payload-cov-');
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test('executable payload rejects a missing source executable', () async {
    final payload = ExecutablePayload(
      executablePath: p.join(temporary.path, 'nope.exe'),
      executableName: 'tool.exe',
    );

    await expectLater(
      payload.stage(p.join(temporary.path, 'staged')),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
  });

  test('directory payload rejects a missing source directory', () async {
    final payload = DirectoryPayload(
      directoryPath: p.join(temporary.path, 'missing-dir'),
      launcherRelativePath: 'launcher',
    );

    await expectLater(
      payload.stage(p.join(temporary.path, 'staged')),
      throwsA(isA<ShipworldException>()),
    );
  });

  test('directory payload fails when the staged launcher is absent', () async {
    final source = Directory(p.join(temporary.path, 'bundle'));
    await source.create();
    await File(p.join(source.path, 'other')).writeAsString('data');
    // A valid relative launcher path that is never produced by staging.
    final payload = DirectoryPayload(
      directoryPath: source.path,
      launcherRelativePath: 'launcher',
    );

    await expectLater(
      payload.stage(p.join(temporary.path, 'staged')),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
  });

  test('directory payload preserves an internal symlink', () async {
    if (!await _symlinksSupported(temporary.path)) {
      markTestSkipped('symlinks are unavailable on this host');
      return;
    }

    final source = Directory(p.join(temporary.path, 'bundle'));
    await Directory(p.join(source.path, 'data')).create(recursive: true);
    await File(p.join(source.path, 'app')).writeAsString('launcher');
    // A relative symlink is reported as a Link by list() only when it does
    // not resolve to an existing entity, so target a missing sibling that
    // still normalizes inside the payload root.
    await Link(p.join(source.path, 'alias'))
        .create(p.join('data', 'missing-asset'));

    final payload = DirectoryPayload(
      directoryPath: source.path,
      launcherRelativePath: 'app',
    );
    final destination = p.join(temporary.path, 'staged');

    await payload.stage(destination);

    expect(await Link(p.join(destination, 'alias')).exists(), isTrue);
  });

  test('directory payload rejects a symlink escaping the root', () async {
    if (!await _symlinksSupported(temporary.path)) {
      markTestSkipped('symlinks are unavailable on this host');
      return;
    }

    final source = Directory(p.join(temporary.path, 'bundle'));
    await source.create();
    await File(p.join(source.path, 'app')).writeAsString('launcher');
    // Absolute symlink pointing outside the payload root. It is left broken so
    // list() reports it as a Link and the escape guard runs.
    await Link(p.join(source.path, 'escape'))
        .create(p.join(temporary.path, 'outside-missing.txt'));

    final payload = DirectoryPayload(
      directoryPath: source.path,
      launcherRelativePath: 'app',
    );

    await expectLater(
      payload.stage(p.join(temporary.path, 'staged')),
      throwsA(
        isA<ShipworldException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
  });
}
