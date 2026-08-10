import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler ISO-2022 character sets', () {
    test('should map G0 line drawing via ESC ( 0', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      await terminal.writeAndWait('\x1b(0q\x1b(Bq');

      expect(_line(terminal), '\u2500q');
    });

    test('should map G1 line drawing after ESC ) 0 and SO', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      await terminal.writeAndWait('\x1b)0\x0eq\x0f\x1b(Bq');

      expect(_line(terminal), '\u2500q');
    });

    test('should restore charset and glevel on ESC 7 / ESC 8', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      await terminal.writeAndWait('\x1b)0\x0e\x1b7\x0f\x1b(B\x1b8q');

      expect(_line(terminal), '\u2500');
    });
  });
}

String _line(Terminal terminal) =>
    terminal.buffer.active.getLine(0)!.translateToString(trimRight: true);
