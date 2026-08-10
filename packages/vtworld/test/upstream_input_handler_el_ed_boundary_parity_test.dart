import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler EL/ED cursor at buffer.cols', () {
    test('EL0', () => _verifyErase('\x1b[0K', preserveLine: true));
    test('EL1', () => _verifyErase('\x1b[1K'));
    test('EL2', () => _verifyErase('\x1b[2K'));
    test('ED0', () => _verifyErase('\x1b[0J', preserveLine: true));
    test('ED1', () => _verifyErase('\x1b[1J'));
    test('ED2', () => _verifyErase('\x1b[2J'));
    test('ED3', () => _verifyErase('\x1b[3J', preserveLine: true));

    test('cursor never advances beyond cols', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);

      for (final sequence in _cursorSequences) {
        await terminal.writeAndWait('##########\x1b[2J$sequence');
        expect(terminal.buffer.active.cursorX, lessThanOrEqualTo(10));
        terminal.reset();
      }
    });
  });
}

Future<void> _verifyErase(String sequence, {bool preserveLine = false}) async {
  final terminal = _terminal();
  try {
    await terminal.writeAndWait('##########$sequence');
    expect(terminal.buffer.active.cursorX, 10);
    expect(_lines(terminal), <String>[
      if (preserveLine) '##########' else '',
      '',
      '',
      '',
      '',
    ]);
  } finally {
    terminal.dispose();
  }
}

Terminal _terminal() => Terminal(options: TerminalOptions(cols: 10, rows: 5));

List<String> _lines(Terminal terminal) => <String>[
  for (var row = 0; row < terminal.rows; row++)
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true),
];

const _cursorSequences = <String>[
  '\x1b[10@',
  '\x1b[10 @',
  '\x1b[10A',
  '\x1b[10 A',
  '\x1b[10B',
  '\x1b[10C',
  '\x1b[10D',
  '\x1b[10E',
  '\x1b[10F',
  '\x1b[10G',
  '\x1b[10;10H',
  '\x1b[10I',
  '\x1b[10L',
  '\x1b[10M',
  '\x1b[10P',
  '\x1b[10S',
  '\x1b[10T',
  '\x1b[10X',
  '\x1b[10Z',
  '\x1b[10`',
  '\x1b[10a',
  '\x1b[10b',
  '\x1b[10d',
  '\x1b[10e',
  '\x1b[10;10f',
  '\x1b[0g',
  '\x1b[s',
  "\x1b[10'}",
  "\x1b[10'~",
];
