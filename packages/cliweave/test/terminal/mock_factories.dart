// Dart port of the terminal-stream subset of
// `packages/cli/src/test/helpers/mock-factories.ts`.

import 'package:cliweave/terminal.dart';

/// Mirror of the TS `MockStream`: records writes and counts the
/// clearLine/cursorTo spy calls.
class MockStream implements WriteStream {
  MockStream({this.isTTY = true});

  @override
  final bool isTTY;

  final List<String> writes = [];
  int clearLineCalls = 0;
  int cursorToCalls = 0;

  /// The `dir` argument of each [clearLine] call, in order.
  final List<int> clearLineDirs = [];

  /// An ordered log of every terminal operation, so tests can assert the exact
  /// sequence of a rendered frame (`cursorTo` -> `write` -> `clearLine`).
  final List<String> operations = [];

  @override
  void write(String chunk) {
    writes.add(chunk);
    operations.add('write');
  }

  @override
  void clearLine(int dir) {
    clearLineCalls++;
    clearLineDirs.add(dir);
    operations.add('clearLine:$dir');
  }

  @override
  void cursorTo(int column) {
    cursorToCalls++;
    operations.add('cursorTo:$column');
  }
}

MockStream createMockStream([bool isTTY = true]) {
  return MockStream(isTTY: isTTY);
}
