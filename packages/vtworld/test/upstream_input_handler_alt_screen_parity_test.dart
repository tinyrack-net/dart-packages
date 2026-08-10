import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler alternate screen', () {
    test('handles mode 47 alternate buffer', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?47h\r\n\x1b[31mJUNK\x1b[?47lTEST');
      expect(_line(terminal, 0), '');
      expect(_line(terminal, 1), '    TEST');
      expect(terminal.buffer.active.getLine(1)!.getCell(4)!.foreground, 1);
    });

    test('handles mode 1047 alternate buffer', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?1047h\r\n\x1b[31mJUNK\x1b[?1047lTEST');
      expect(_line(terminal, 0), '');
      expect(_line(terminal, 1), '    TEST');
      expect(terminal.buffer.active.getLine(1)!.getCell(4)!.foreground, 1);
    });

    test('handles mode 1048 saved cursor', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?1048h\r\n\x1b[31mJUNK\x1b[?1048lTEST');
      expect(_line(terminal, 0), 'TEST');
      expect(_line(terminal, 1), 'JUNK');
      expect(
        terminal.buffer.active.getLine(0)!.getCell(0)!.foregroundMode,
        TerminalColorMode.defaultColor,
      );
      expect(terminal.buffer.active.getLine(1)!.getCell(0)!.foreground, 1);
    });

    test('handles mode 1049 alternate buffer and cursor', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?1049h\r\n\x1b[31mJUNK\x1b[?1049lTEST');
      expect(_line(terminal, 0), 'TEST');
      expect(_line(terminal, 1), '');
      expect(
        terminal.buffer.active.getLine(0)!.getCell(0)!.foregroundMode,
        TerminalColorMode.defaultColor,
      );
    });

    test('mode 1049 maintains alternate saved cursor', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b[?1049h\r\n\x1b[31m\x1b[s\x1b[?1049lTEST',
      );
      expect(_line(terminal, 0), 'TEST');
      expect(
        terminal.buffer.active.getLine(0)!.getCell(0)!.foregroundMode,
        TerminalColorMode.defaultColor,
      );
      await terminal.writeAndWait('\x1b[?1049h\x1b[uTEST');
      expect(_line(terminal, 1), 'TEST');
      expect(terminal.buffer.active.getLine(1)!.getCell(0)!.foreground, 1);
    });

    test('mode 1049 clears alternate buffer with erase attributes', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[42m\x1b[?1049h');
      final cell = terminal.buffer.active.getLine(20)!.getCell(10)!;
      expect(cell.backgroundMode, TerminalColorMode.palette);
      expect(cell.background, 2);
    });
  });
}

String _line(Terminal terminal, int row) =>
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true);
