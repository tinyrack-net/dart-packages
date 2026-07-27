import 'package:cliweave/terminal.dart';
import 'package:test/test.dart';

import 'mock_factories.dart';

void main() {
  test('logger defaults use the package theme and spinner', () {
    final stdout = createMockStream(false);
    final stderr = createMockStream(false);
    final logger = createCliLogger(stdout: stdout, stderr: stderr);

    logger.success('done');
    logger.error('bad');
    logger.spinner('working').succeed('complete');

    expect(stdout.writes.join(), contains('done'));
    expect(stdout.writes.join(), contains('complete'));
    expect(stderr.writes.join(), contains('bad'));
  });

  test('spinner default timer can start and stop on a TTY', () {
    final stream = createMockStream();
    final spinner = createSpinner(stream, 'working', readEnv: (name) => null);

    spinner.stop();

    expect(stream.writes, isNotEmpty);
    expect(stream.clearLineCalls, greaterThan(0));
    expect(stream.cursorToCalls, greaterThan(0));
  });

  test('spinner recognizes CI, NO_COLOR, and FORCE_COLOR=0', () {
    for (final environment in [
      const {'CI': '1'},
      const {'NO_COLOR': '1'},
      const {'FORCE_COLOR': '0'},
    ]) {
      final stream = createMockStream();
      final spinner = createSpinner(
        stream,
        'working',
        readEnv: environment._read,
      );

      expect(stream.clearLineCalls, 0);
      spinner.succeed('done');
      expect(stream.writes.join(), contains('done'));
      expect(stream.clearLineCalls, 1);
    }
  });
}

extension on Map<String, String> {
  String? _read(String name) => this[name];
}
