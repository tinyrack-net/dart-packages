import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler cursor positioning clamp', () {
    test('CUF', () => _verifyClamp('\x1b[C', (9, 9), (1, 0)));
    test('CUB', () => _verifyClamp('\x1b[D', (8, 9), (0, 0)));
    test('CUD', () => _verifyClamp('\x1b[B', (9, 9), (0, 1)));
    test('CUU', () => _verifyClamp('\x1b[A', (9, 8), (0, 0)));
    test('CNL', () => _verifyClamp('\x1b[E', (0, 9), (0, 1)));
    test('CPL', () => _verifyClamp('\x1b[F', (0, 8), (0, 0)));
    test('CHA', () => _verifyClamp('\x1b[5G', (4, 9), (4, 0)));
    test('CUP', () => _verifyClamp('\x1b[5;5H', (4, 4), (4, 4)));
    test('HPA', () => _verifyClamp('\x1b[5`', (4, 9), (4, 0)));
    test('HPR', () => _verifyClamp('\x1b[a', (9, 9), (1, 0)));
    test('VPA', () => _verifyClamp('\x1b[5d', (9, 4), (0, 4)));
    test('VPR', () => _verifyClamp('\x1b[e', (9, 9), (0, 1)));
    test('DCH', () => _verifyClamp('\x1b[P', (9, 9), (0, 0)));
    test('ECH', () => _verifyClamp('\x1b[X', (9, 9), (0, 0)));
    test('ICH', () => _verifyClamp('\x1b[@', (9, 9), (0, 0)));

    test('DCH - should delete last cell', () => _verifyLastCell('\x1b[P'));
    test('ECH - should delete last cell', () => _verifyLastCell('\x1b[X'));
    test('ICH - should delete last cell', () => _verifyLastCell('\x1b[@'));
  });
}

Future<void> _verifyClamp(
  String sequence,
  (int x, int y) high,
  (int x, int y) low,
) async {
  final terminal = _terminal();
  try {
    terminal.buffer.active
      ..cursorX = 10000
      ..cursorY = 10000;
    await terminal.writeAndWait(sequence);
    _expectCursor(terminal, high);
    terminal.buffer.active
      ..cursorX = -10000
      ..cursorY = -10000;
    await terminal.writeAndWait(sequence);
    _expectCursor(terminal, low);
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyLastCell(String sequence) async {
  final terminal = _terminal();
  try {
    await terminal.writeAndWait('0123456789$sequence');
    expect(
      terminal.buffer.active.getLine(0)!.translateToString(),
      '012345678 ',
    );
  } finally {
    terminal.dispose();
  }
}

Terminal _terminal() => Terminal(options: TerminalOptions(cols: 10, rows: 10));

void _expectCursor(Terminal terminal, (int x, int y) position) {
  expect(terminal.buffer.active.cursorX, position.$1);
  expect(terminal.buffer.active.cursorY, position.$2);
}
