import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler print', () {
    test('should not cause an infinite loop (regression test)', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final lineCount = terminal.buffer.active.length;
      await terminal.writeAndWait('\u200b');
      expect(terminal.buffer.active.cursorY, 0);
      expect(terminal.buffer.active.length, lineCount);
    });

    test('should join combining characters in a single print', () async {
      await _verifyText('e\u0301', 'e\u0301', 1);
    });

    test('should join combining characters split across parse calls', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('e');
      await terminal.writeAndWait('\u0301');
      _expectText(terminal, 'e\u0301', 1);
    });

    test('should repeat preceding grapheme cluster via REP', () async {
      await _verifyText('e\u0301\x1b[2b', 'e\u0301e\u0301e\u0301', 3);
    });

    test('should not repeat when REP has no preceding join state', () async {
      await _verifyText('\x1b[2b', '', 0);
    });

    test('should not repeat after an intervening escape sequence', () async {
      await _verifyText('a\x1b[0m\x1b[2b', 'a', 1);
    });

    test('should clear cells to the right on early wrap-around', () async {
      final terminal = Terminal(
        options: TerminalOptions(cols: 5, rows: 5, scrollback: 1),
      );
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('12345\r￥￥￥');
      expect(_line(terminal, 0), '￥￥');
      expect(_line(terminal, 1), '￥');
    });

    test('should strip soft hyphens (U+00AD)', () async {
      await _verifyText('Soft\xadhy\xadphen', 'Softhyphen', 10);
    });
  });
}

Future<void> _verifyText(String input, String text, int cursorX) async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait(input);
    _expectText(terminal, text, cursorX);
  } finally {
    terminal.dispose();
  }
}

void _expectText(Terminal terminal, String text, int cursorX) {
  expect(_line(terminal, 0), text);
  expect(terminal.buffer.active.cursorX, cursorX);
}

String _line(Terminal terminal, int row) =>
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true);
