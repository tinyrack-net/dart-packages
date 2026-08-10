import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler remaining upstream parity', () {
    test('should not reverse outside of scroll margins', () async {
      final terminal = _terminal(cols: 5, rows: 5, scrollback: 1);
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('#####abcdefghijklmnopqrstuvwxy');
      await terminal.writeAndWait('\x1b[?45h');
      await terminal.writeAndWait('\x1b[2;4r\x1b[5;6H');
      await terminal.writeAndWait(_repeat(_ttyBackspace, 100));
      expect(terminal.buffer.active.cursorY, 4);
      expect(terminal.buffer.active.cursorX, 0);
      await terminal.writeAndWait('\x1b[4;6H');
      await terminal.writeAndWait(_repeat(_ttyBackspace, 100));
      expect(terminal.buffer.active.cursorY, 1);
      expect(terminal.buffer.active.cursorX, 0);
    });

    test('ED2 with scrollOnEraseInDisplay turned on', () async {
      final terminal = _terminal(
        cols: 10,
        rows: 5,
        scrollback: 20,
        scrollOnEraseInDisplay: true,
      );
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(_repeat('a', 20));
      await terminal.writeAndWait('\x1b[2J');
      expect(terminal.buffer.active.baseY, 2);
      expect(_line(terminal, 0), _repeat('a', 10));
      expect(_line(terminal, 1), _repeat('a', 10));
    });

    test('insertChars', () async {
      final terminal = _terminal(rows: 3);
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('${_repeat('a', 70)}1234567890\x1b[1;71H');
      await terminal.writeAndWait('\x1b[@\x1b[@\x1b[2@');
      expect(_line(terminal, 0), '${_repeat('a', 70)}    123456');
      await terminal.writeAndWait('\x1b[10@');
      expect(_line(terminal, 0), _repeat('a', 70));
    });

    test('deleteChars', () async {
      final terminal = _terminal(rows: 3);
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('${_repeat('a', 70)}1234567890\x1b[1;71H');
      await terminal.writeAndWait('\x1b[P\x1b[P\x1b[2P');
      expect(_line(terminal, 0), '${_repeat('a', 70)}567890');
      await terminal.writeAndWait('\x1b[10P');
      expect(_line(terminal, 0), _repeat('a', 70));
    });

    test('eraseInLine', () async {
      final terminal = _terminal(rows: 3);
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(_repeat('a', 240));
      await terminal.writeAndWait('\x1b[1;71H\x1b[K');
      expect(_line(terminal, 0), _repeat('a', 70));
      await terminal.writeAndWait('\x1b[2;71H\x1b[1K');
      expect(_line(terminal, 1), '${_repeat(' ', 71)}${_repeat('a', 9)}');
      await terminal.writeAndWait('\x1b[3;71H\x1b[2K');
      expect(_line(terminal, 2), '');
    });

    test('eraseInLine reflow', () async {
      final terminal = _terminal(cols: 10, rows: 5);
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(_repeat('a', 15));
      expect(terminal.buffer.active.getLine(1)!.isWrapped, isTrue);
      await terminal.writeAndWait('\x1b[2;2H\x1b[K');
      expect(terminal.buffer.active.getLine(1)!.isWrapped, isTrue);
      await terminal.writeAndWait('\x1b[2;1H\x1b[K');
      expect(terminal.buffer.active.getLine(1)!.isWrapped, isFalse);
      await terminal.writeAndWait('${_repeat('a', 15)}\x1b[4;2H\x1b[2K');
      expect(terminal.buffer.active.getLine(3)!.isWrapped, isFalse);
    });

    test('eraseInDisplay', () async {
      final terminal = _terminal(cols: 10, rows: 4);
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('111111111122222222223333333333');
      await terminal.writeAndWait('\x1b[2;6H\x1b[J');
      expect(_line(terminal, 0), '1111111111');
      expect(_line(terminal, 1), '22222');
      expect(_line(terminal, 2), '');
      await terminal.writeAndWait('\x1b[2;6H\x1b[1J');
      expect(_line(terminal, 0), '');
      expect(_line(terminal, 1), '');
    });

    test(
      'setCursorStyle should call Terminal.setOption with correct params',
      () async {
        final terminal = _terminal();
        addTearDown(terminal.dispose);
        const expected = <(int, TerminalCursorStyle, bool)>[
          (1, TerminalCursorStyle.block, true),
          (2, TerminalCursorStyle.block, false),
          (3, TerminalCursorStyle.underline, true),
          (4, TerminalCursorStyle.underline, false),
          (5, TerminalCursorStyle.bar, true),
          (6, TerminalCursorStyle.bar, false),
        ];
        for (final value in expected) {
          await terminal.writeAndWait('\x1b[${value.$1} q');
          expect(terminal.modes.cursorStyle, value.$2);
          expect(terminal.modes.cursorBlink, value.$3);
        }
        await terminal.writeAndWait('\x1b[0 q');
        expect(terminal.modes.cursorStyle, terminal.options.cursorStyle);
        expect(terminal.modes.cursorBlink, terminal.options.cursorBlink);
      },
    );

    test('should toggle bracketedPasteMode', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?2004h');
      expect(terminal.modes.bracketedPasteMode, isTrue);
      await terminal.writeAndWait('\x1b[?2004l');
      expect(terminal.modes.bracketedPasteMode, isFalse);
    });

    test('should toggle colorSchemeUpdates (DECSET 2031)', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?2031h');
      expect(terminal.modes.colorSchemeUpdates, isTrue);
      await terminal.writeAndWait('\x1b[?2031l');
      expect(terminal.modes.colorSchemeUpdates, isFalse);
    });

    test(
      'should not toggle colorSchemeUpdates when colorSchemeQuery is disabled',
      () async {
        final terminal = Terminal(
          options: TerminalOptions(
            vtExtensions: const TerminalVtExtensions(colorSchemeQuery: false),
          ),
        );
        addTearDown(terminal.dispose);
        await terminal.writeAndWait('\x1b[?2031h');
        expect(terminal.modes.colorSchemeUpdates, isFalse);
      },
    );

    test('should parse big chunks in smaller subchunks', () async {
      final terminal = _terminal(cols: 10, rows: 10, scrollback: 30000);
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(_repeat('a', 300000));
      expect(terminal.buffer.active.cursorX, 10);
      expect(terminal.buffer.active.getLine(0)!.getCell(0)!.chars, 'a');
      expect(terminal.buffer.active.currentLine.getCell(9)!.chars, 'a');
    });

    test('all should be disabled by default and not report', () async {
      final terminal = _terminal(cols: 10, rows: 10);
      addTearDown(terminal.dispose);
      final data = <String>[];
      terminal.onData.listen(data.add);
      await terminal.writeAndWait('\x1b[14t\x1b[16t\x1b[18t\x1b[20t\x1b[21t');
      expect(data, isEmpty);
    });

    test('14 - GetWinSizePixels', () async {
      final terminal = Terminal(
        options: TerminalOptions(
          windowOptions: const TerminalWindowOptions(getWinSizePixels: true),
        ),
      );
      addTearDown(terminal.dispose);
      final data = <String>[];
      terminal.onData.listen(data.add);
      await terminal.writeAndWait('\x1b[14t');
      expect(data, isEmpty);
    });

    test('16 - GetCellSizePixels', () async {
      final terminal = Terminal(
        options: TerminalOptions(
          windowOptions: const TerminalWindowOptions(getCellSizePixels: true),
        ),
      );
      addTearDown(terminal.dispose);
      final data = <String>[];
      terminal.onData.listen(data.add);
      await terminal.writeAndWait('\x1b[16t');
      expect(data, isEmpty);
    });

    test('18 - GetWinSizeChars', () async {
      final terminal = Terminal(
        options: TerminalOptions(
          cols: 10,
          rows: 10,
          windowOptions: const TerminalWindowOptions(getWinSizeChars: true),
        ),
      );
      addTearDown(terminal.dispose);
      final data = <String>[];
      terminal.onData.listen(data.add);
      await terminal.writeAndWait('\x1b[18t');
      expect(data, <String>['\x1b[8;10;10t']);
      terminal.resize(50, 20);
      await terminal.writeAndWait('\x1b[18t');
      expect(data.last, '\x1b[8;20;50t');
    });

    test('22/23 - PushTitle/PopTitle', () async {
      await _verifyTitleStack(0, <String>['1', '2', '3', '3', '2', '1']);
    });

    test('22/23 - PushTitle/PopTitle with ;1', () async {
      await _verifyTitleStack(1, <String>['1', '2', '3']);
    });

    test('22/23 - PushTitle/PopTitle with ;2', () async {
      await _verifyTitleStack(2, <String>['1', '2', '3', '3', '2', '1']);
    });

    test(
      'DECCOLM - should only work with "SetWinLines" (24) enabled',
      () async {
        final disabled = _terminal(cols: 10, rows: 10);
        addTearDown(disabled.dispose);
        await disabled.writeAndWait('\x1b[?3l\x1b[?3h');
        expect(disabled.cols, 10);

        final enabled = Terminal(
          options: TerminalOptions(
            cols: 10,
            rows: 10,
            windowOptions: const TerminalWindowOptions(setWinLines: true),
          ),
        );
        addTearDown(enabled.dispose);
        await enabled.writeAndWait('\x1b[?3l');
        expect(enabled.cols, 80);
        await enabled.writeAndWait('\x1b[?3h');
        expect(enabled.cols, 132);
      },
    );

    test('should correctly reset cells taken by wide chars print', () async {
      final terminal = await _wideTerminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[H#\x1b[1;6H######');
      expect(_lines(terminal), <String>[
        '# ￥ #####',
        '# ￥￥￥￥',
        '￥￥￥￥￥',
        '￥￥￥￥￥',
        '',
      ]);
    });

    test('should correctly reset cells taken by wide chars EL', () async {
      final terminal = await _wideTerminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[1;6H\x1b[K#\x1b[2;5H\x1b[1K');
      expect(_lines(terminal).take(2), <String>['￥￥ #', '      ￥￥']);
    });

    test('should correctly reset cells taken by wide chars ICH', () async {
      final terminal = await _wideTerminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[1;6H\x1b[@\x1b[2;4H\x1b[2@');
      expect(_lines(terminal).take(2), <String>['￥￥   ￥', '￥    ￥￥']);
    });

    test('should correctly reset cells taken by wide chars DCH', () async {
      final terminal = await _wideTerminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[1;6H\x1b[P\x1b[2;6H\x1b[2P');
      expect(_lines(terminal).take(2), <String>['￥￥ ￥￥', '￥￥  ￥']);
    });

    test('should correctly reset cells taken by wide chars ECH', () async {
      final terminal = await _wideTerminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[1;6H\x1b[X\x1b[2;6H\x1b[2X');
      expect(_lines(terminal).take(2), <String>['￥￥  ￥￥', '￥￥    ￥']);
    });
  });
}

Future<void> _verifyTitleStack(int selector, List<String> expected) async {
  final terminal = Terminal(
    options: TerminalOptions(
      windowOptions: const TerminalWindowOptions(
        pushTitle: true,
        popTitle: true,
      ),
    ),
  );
  try {
    final titles = <String>[];
    terminal.onTitleChange.listen(titles.add);
    final suffix = selector == 0 ? '' : ';$selector';
    for (var value = 1; value <= 3; value++) {
      await terminal.writeAndWait('\x1b]0;$value\x07\x1b[22${suffix}t');
    }
    for (var count = 0; count < 4; count++) {
      await terminal.writeAndWait('\x1b[23${suffix}t');
    }
    expect(titles, expected);
  } finally {
    terminal.dispose();
  }
}

Future<Terminal> _wideTerminal() async {
  final terminal = _terminal(cols: 10, rows: 5, scrollback: 1);
  await terminal.writeAndWait(_repeat('￥', 20));
  return terminal;
}

Terminal _terminal({
  int cols = 80,
  int rows = 30,
  int scrollback = 1000,
  bool scrollOnEraseInDisplay = false,
}) => Terminal(
  options: TerminalOptions(
    cols: cols,
    rows: rows,
    scrollback: scrollback,
    scrollOnEraseInDisplay: scrollOnEraseInDisplay,
  ),
);

String _line(Terminal terminal, int row) =>
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true);

List<String> _lines(Terminal terminal) => <String>[
  for (var row = 0; row < terminal.rows; row++) _line(terminal, row),
];

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();

const _ttyBackspace = '\x08 \x08';
