import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/release.dart';
import 'package:test/test.dart';

Matcher _throwsMessage(Pattern pattern) {
  return throwsA(predicate((Object? error) => '$error'.contains(pattern)));
}

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('shipworld-vfiles-');
  });

  tearDown(() async {
    if (temporary.existsSync()) {
      await temporary.delete(recursive: true);
    }
  });

  test('reports a missing version file as a ShipworldException', () async {
    final missing = p.join(temporary.path, 'does-not-exist', 'pubspec.yaml');

    await expectLater(
      readPubspecVersion(missing),
      _throwsMessage('Version file not found'),
    );
  });

  test('rejects a pubspec whose document is not a map', () async {
    final filePath = p.join(temporary.path, 'pubspec.yaml');
    // A top-level scalar parses to a non-YamlMap document.
    await File(filePath).writeAsString('42\n');

    await expectLater(
      readPubspecVersion(filePath),
      _throwsMessage('Invalid pubspec.yaml'),
    );
  });
}
