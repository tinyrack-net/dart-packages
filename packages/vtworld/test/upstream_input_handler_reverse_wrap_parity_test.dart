import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler BS reverseWraparound', () {
    test('reverseWraparound unset cannot delete last cell', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('12345$_ttyBackspace');
      expect(_lines(terminal, 1), <String>['123 5']);
      await terminal.writeAndWait(_repeat(_ttyBackspace, 10));
      expect(_lines(terminal, 1), <String>['    5']);
    });

    test('reverseWraparound unset cannot access previous line', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('${_repeat('12345', 2)}$_ttyBackspace');
      expect(_lines(terminal, 2), <String>['12345', '123 5']);
      await terminal.writeAndWait(_repeat(_ttyBackspace, 10));
      expect(_lines(terminal, 2), <String>['12345', '    5']);
    });

    test('reverseWraparound set can delete last cell', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?45h12345$_ttyBackspace');
      expect(_lines(terminal, 1), <String>['1234 ']);
      await terminal.writeAndWait(_repeat(_ttyBackspace, 7));
      expect(_lines(terminal, 1), <String>['     ']);
    });

    test('reverseWraparound set can access previous wrapped line', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b[?45h${_repeat('12345', 2)}$_ttyBackspace',
      );
      expect(_lines(terminal, 2), <String>['12345', '1234 ']);
      await terminal.writeAndWait(_repeat(_ttyBackspace, 7));
      expect(_lines(terminal, 2), <String>['12   ', '     ']);
    });

    test('reverseWraparound set lifts wrapped state', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?45h${_repeat('12345', 2)}');
      expect(terminal.buffer.active.getLine(1)!.isWrapped, isTrue);
      await terminal.writeAndWait(_repeat(_ttyBackspace, 7));
      expect(terminal.buffer.active.getLine(1)!.isWrapped, isFalse);
    });

    test('reverseWraparound set stops at hard newlines', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b[?45h12345\r\n${_repeat('12345', 2)}'
        '${_repeat(_ttyBackspace, 50)}',
      );
      expect(_lines(terminal, 3), <String>['12345', '     ', '     ']);
      expect(terminal.buffer.active.cursorX, 0);
      expect(terminal.buffer.active.cursorY, 1);
    });

    test('reverseWraparound set handles wide characters', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?45h￥￥￥');
      expect(_lines(terminal, 2), <String>['￥￥', '￥']);
      await terminal.writeAndWait(_ttyBackspace);
      expect(_lines(terminal, 2), <String>['￥￥', '  ']);
      expect(terminal.buffer.active.cursorX, 1);
      await terminal.writeAndWait(_ttyBackspace);
      expect(_lines(terminal, 2), <String>['￥￥', '  ']);
      expect(terminal.buffer.active.cursorX, 0);
      await terminal.writeAndWait(_ttyBackspace);
      expect(_lines(terminal, 2), <String>['￥  ', '  ']);
      expect(terminal.buffer.active.cursorX, 3);
      await terminal.writeAndWait(_ttyBackspace);
      expect(terminal.buffer.active.cursorX, 2);
      await terminal.writeAndWait(_ttyBackspace);
      expect(_lines(terminal, 2), <String>['    ', '  ']);
      expect(terminal.buffer.active.cursorX, 1);
      await terminal.writeAndWait(_ttyBackspace);
      expect(terminal.buffer.active.cursorX, 0);
    });
  });
}

const _ttyBackspace = '\x08 \x08';

Terminal _terminal() =>
    Terminal(options: TerminalOptions(cols: 5, rows: 5, scrollback: 1));

List<String> _lines(Terminal terminal, int count) => <String>[
  for (var row = 0; row < count; row++)
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true),
];

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();
