import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler DECSTBM scroll margins', () {
    test('defaults to whole viewport', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[r');
      expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (0, 9));
      await terminal.writeAndWait('\x1b[3;7r');
      expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (2, 6));
      await terminal.writeAndWait('\x1b[0;0r');
      expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (0, 9));
    });

    test('clamps bottom', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[3;1000r');
      expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (2, 9));
    });

    test('only applies for top less than bottom', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[7;2r');
      expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (0, 9));
    });

    test('homes cursor', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[10;10H\x1b[2;7r');
      expect(
        (terminal.buffer.active.cursorX, terminal.buffer.active.cursorY),
        (0, 0),
      );
    });
  });
}

Terminal _terminal() => Terminal(options: TerminalOptions(cols: 10, rows: 10));
