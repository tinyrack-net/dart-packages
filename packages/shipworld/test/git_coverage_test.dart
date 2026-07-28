import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shipworld/shipworld.dart';
import 'package:test/test.dart';

Matcher throwsCode(String code) => throwsA(
  isA<ShipworldException>().having((error) => error.code, 'code', code),
);

void main() {
  test('reports failures to start the git process', () async {
    final base = await Directory.systemTemp.createTemp('shipworld-git-');
    addTearDown(() => base.delete(recursive: true));
    // Point at a directory that does not exist so the process cannot start.
    final missing = p.join(base.path, 'no-such-directory');

    await expectLater(
      const IoGitClient().run(['status'], workingDirectory: missing),
      throwsCode('git_start_failed'),
    );
  });

  test('reports non-zero git exit codes', () async {
    final temporary = await Directory.systemTemp.createTemp('shipworld-git-');
    addTearDown(() => temporary.delete(recursive: true));

    // A fresh, non-initialized directory makes git fail with a non-zero exit.
    await expectLater(
      const IoGitClient().run([
        'status',
        '--porcelain',
      ], workingDirectory: temporary.path),
      throwsCode('git_command_failed'),
    );
  });
}
