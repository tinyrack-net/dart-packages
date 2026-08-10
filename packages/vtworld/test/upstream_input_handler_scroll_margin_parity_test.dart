import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('save and restore cursor', () async {
    final terminal = _terminal();
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('\x1b[3;2H\x1b[33m\x1b7');
    await terminal.writeAndWait('\x1b[10;10H\x1b[30m\x1b8X');
    expect(terminal.buffer.active.cursorX, 2);
    expect(terminal.buffer.active.cursorY, 2);
    expect(terminal.buffer.active.getLine(2)!.getCell(1)!.foreground, 3);
  });

  group('InputHandler scroll margins', () {
    test('scrollUp', () async {
      final terminal = await _filled();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[2;4r\x1b[2Sm');
      expect(_lines(terminal), <String>[
        'm',
        '3',
        '',
        '',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
      ]);
    });

    test('scrollDown', () async {
      final terminal = await _filled();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[2;4r\x1b[2Tm');
      expect(_lines(terminal), <String>[
        'm',
        '',
        '',
        '1',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
      ]);
    });

    test('insertLines - out of margins', () async {
      final terminal = await _filled();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[3;6r\x1b[2Lm');
      expect(_lines(terminal), <String>[
        'm',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
      ]);
      await terminal.writeAndWait('\x1b[2H\x1b[2Ln');
      await terminal.writeAndWait('\x1b[7H\x1b[2Lo\x1b[8H\x1b[2Lp');
      await terminal.writeAndWait('\x1b[100H\x1b[2Lq');
      expect(_lines(terminal), <String>[
        'm',
        'n',
        '2',
        '3',
        '4',
        '5',
        'o',
        'p',
        '8',
        'q',
      ]);
    });

    test('insertLines - within margins', () async {
      final terminal = await _filled();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[3;6r\x1b[3H\x1b[2Lm');
      expect(_lines(terminal), <String>[
        '0',
        '1',
        'm',
        '',
        '2',
        '3',
        '6',
        '7',
        '8',
        '9',
      ]);
      await terminal.writeAndWait('\x1b[6H\x1b[2Ln');
      expect(_lines(terminal), <String>[
        '0',
        '1',
        'm',
        '',
        '2',
        'n',
        '6',
        '7',
        '8',
        '9',
      ]);
    });

    test('deleteLines - out of margins', () async {
      final terminal = await _filled();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[3;6r\x1b[2Mm');
      expect(_lines(terminal), <String>[
        'm',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
      ]);
      await terminal.writeAndWait('\x1b[2H\x1b[2Mn');
      await terminal.writeAndWait('\x1b[7H\x1b[2Mo\x1b[8H\x1b[2Mp');
      await terminal.writeAndWait('\x1b[100H\x1b[2Mq');
      expect(_lines(terminal), <String>[
        'm',
        'n',
        '2',
        '3',
        '4',
        '5',
        'o',
        'p',
        '8',
        'q',
      ]);
    });

    test('deleteLines - within margins', () async {
      final terminal = await _filled();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[3;6r\x1b[6H\x1b[2Mm');
      expect(_lines(terminal), <String>[
        '0',
        '1',
        '2',
        '3',
        '4',
        'm',
        '6',
        '7',
        '8',
        '9',
      ]);
      await terminal.writeAndWait('\x1b[3H\x1b[2Mn');
      expect(_lines(terminal), <String>[
        '0',
        '1',
        'n',
        'm',
        '',
        '',
        '6',
        '7',
        '8',
        '9',
      ]);
    });
  });
}

Future<Terminal> _filled() async {
  final terminal = _terminal();
  await terminal.writeAndWait('0\r\n1\r\n2\r\n3\r\n4\r\n5\r\n6\r\n7\r\n8\r\n9');
  return terminal;
}

Terminal _terminal() => Terminal(options: TerminalOptions(cols: 10, rows: 10));

List<String> _lines(Terminal terminal) => <String>[
  for (var row = 0; row < 10; row++)
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true),
];
