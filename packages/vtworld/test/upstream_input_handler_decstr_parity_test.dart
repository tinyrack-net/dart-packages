import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler DECSTR', () {
    test('resets insert mode', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[4h');
      expect(terminal.modes.insertMode, isTrue);
      await terminal.writeAndWait('\x1b[!p');
      expect(terminal.modes.insertMode, isFalse);
    });

    test('resets cursor visibility', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?25l');
      expect(terminal.modes.showCursor, isFalse);
      await terminal.writeAndWait('\x1b[!p');
      expect(terminal.modes.showCursor, isTrue);
    });

    test('resets scroll margins', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[2;4r');
      expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (1, 3));
      await terminal.writeAndWait('\x1b[!p');
      expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (0, 4));
    });

    test('resets text attributes', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[1;2;32;43m\x1b[!pX');
      final cell = terminal.buffer.active.getLine(0)!.getCell(0)!;
      expect(cell.isBold, isFalse);
      expect(cell.isDim, isFalse);
      expect(cell.foregroundMode, TerminalColorMode.defaultColor);
      expect(cell.backgroundMode, TerminalColorMode.defaultColor);
    });

    test('resets saved cursor data', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('01234567890123\x1b7');
      expect(
        (
          terminal.buffer.active.savedCursorX,
          terminal.buffer.active.savedCursorY,
        ),
        (4, 1),
      );
      await terminal.writeAndWait('\x1b[!p');
      expect(
        (
          terminal.buffer.active.savedCursorX,
          terminal.buffer.active.savedCursorY,
        ),
        (0, 0),
      );
    });

    test('resets origin mode', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?6h');
      expect(terminal.modes.originMode, isTrue);
      await terminal.writeAndWait('\x1b[!p');
      expect(terminal.modes.originMode, isFalse);
    });
  });
}

Terminal _terminal() =>
    Terminal(options: TerminalOptions(cols: 10, rows: 5, scrollback: 1));
