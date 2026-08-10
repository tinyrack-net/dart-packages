import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test(
    'InputHandler SGR exposes every cell attribute and color form',
    () async {
      final terminal = Terminal(options: TerminalOptions(cols: 40, rows: 2));
      addTearDown(terminal.dispose);

      await terminal.writeAndWait(
        '\u001b[1;2;3;4:2;5;7;8;9;53;38:2::1:2:3;48:5:200;58:2::4:5:6mA'
        '\u001b[22;23;24;25;27;28;29;39;49;55;59mB'
        '\u001b[90;100mC'
        '\u001b[38;5;300;48;2;7;8;9mD'
        '\u001b[4:3mE\u001b[4:4mF\u001b[4:5mG\u001b[0mH',
      );

      final line = terminal.buffer.active.getLine(0)!;
      final a = line.getCell(0)!;
      expect(a.isBold, isTrue);
      expect(a.isDim, isTrue);
      expect(a.isItalic, isTrue);
      expect(a.underlineStyle, TerminalUnderlineStyle.double);
      expect(a.isBlink, isTrue);
      expect(a.isInverse, isTrue);
      expect(a.isInvisible, isTrue);
      expect(a.isStrikethrough, isTrue);
      expect(a.isOverline, isTrue);
      expect(a.foregroundMode, TerminalColorMode.rgb);
      expect((a.foreground, a.background), (0x010203, 200));
      expect(
        (a.underlineColor.red, a.underlineColor.green, a.underlineColor.blue),
        (4, 5, 6),
      );

      final b = line.getCell(1)!;
      expect(b.isAttributeDefault, isTrue);
      final c = line.getCell(2)!;
      expect((c.foreground, c.background), (8, 8));
      final d = line.getCell(3)!;
      expect((d.foreground, d.background), (255, 0x070809));
      expect(line.getCell(4)!.underlineStyle, TerminalUnderlineStyle.curly);
      expect(line.getCell(5)!.underlineStyle, TerminalUnderlineStyle.dotted);
      expect(line.getCell(6)!.underlineStyle, TerminalUnderlineStyle.dashed);
      expect(
        line.getCell(7)!.attributesEqual(terminal.buffer.active.getNullCell()),
        isTrue,
      );
      expect(
        const TerminalCellColor.rgb(1, 2, 3),
        const TerminalCellColor.rgb(1, 2, 3),
      );
      expect(const TerminalCellColor.rgb(1, 2, 3).hashCode, isNot(0));
      expect(
        const TerminalBufferPosition(1, 2),
        const TerminalBufferPosition(1, 2),
      );
      expect(const TerminalBufferPosition(1, 2).hashCode, isNot(0));
    },
  );

  test('InputHandler resets kitty bold and faint independently', () async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 1));
    addTearDown(terminal.dispose);
    await terminal.writeAndWait(
      '\u001b[1;2mA\u001b[221mB\u001b[222mC\u001b[21mD',
    );
    final line = terminal.buffer.active.getLine(0)!;
    expect(line.getCell(0)!.isBold, isTrue);
    expect(line.getCell(0)!.isDim, isTrue);
    expect(line.getCell(1)!.isBold, isFalse);
    expect(line.getCell(1)!.isDim, isTrue);
    expect(line.getCell(2)!.isDim, isFalse);
    expect(line.getCell(3)!.underlineStyle, TerminalUnderlineStyle.double);
  });

  test(
    'InputHandler reports ANSI and DEC modes with exact tri-state values',
    () async {
      final terminal = Terminal(
        options: TerminalOptions(
          convertEol: true,
          quirks: const TerminalQuirks(allowSetCursorBlink: true),
          vtExtensions: const TerminalVtExtensions(win32InputMode: true),
          windowOptions: const TerminalWindowOptions(setWinLines: true),
        ),
      );
      addTearDown(terminal.dispose);
      final data = <String>[];
      terminal.onData.listen(data.add);

      await terminal.writeAndWait(
        '\u001b[4;20h'
        '\u001b[?1;6;7;9;12;25;45;66;1000;1004;1006;1007;'
        '1016;2004;2026;9001h'
        '\u001b[2\u0024p\u001b[4\u0024p\u001b[12\u0024p\u001b[20\u0024p'
        '\u001b[?1\u0024p\u001b[?3\u0024p\u001b[?6\u0024p\u001b[?8\u0024p'
        '\u001b[?9\u0024p\u001b[?12\u0024p\u001b[?67\u0024p'
        '\u001b[?1005\u0024p\u001b[?1015\u0024p\u001b[?9001\u0024p',
      );

      expect(
        data,
        containsAll(<String>[
          '\u001b[2;4\u0024y',
          '\u001b[4;1\u0024y',
          '\u001b[12;3\u0024y',
          '\u001b[20;1\u0024y',
          '\u001b[?1;1\u0024y',
          '\u001b[?3;2\u0024y',
          '\u001b[?6;1\u0024y',
          '\u001b[?8;3\u0024y',
          // Enabling VT200 after X10 replaces the active mouse protocol.
          '\u001b[?9;2\u0024y',
          '\u001b[?12;1\u0024y',
          '\u001b[?67;4\u0024y',
          '\u001b[?1005;4\u0024y',
          '\u001b[?1015;4\u0024y',
          '\u001b[?9001;1\u0024y',
        ]),
      );
      expect(terminal.options.cursorBlink, isTrue);
      expect(terminal.modes.win32InputMode, isTrue);

      await terminal.writeAndWait('\u001b[?12;1006;1007;1016;9001l\u001b[20l');
      expect(terminal.options.cursorBlink, isFalse);
      expect(terminal.modes.win32InputMode, isFalse);
    },
  );

  test('DSR replies distinguish ANSI and private reports', () async {
    final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 2));
    addTearDown(terminal.dispose);
    final data = <String>[];
    terminal.onData.listen(data.add);
    await terminal.writeAndWait('abc\u001b[5n\u001b[?5n\u001b[6n\u001b[?6n');
    expect(data, <String>[
      '\u001b[0n',
      '\u001b[?0n',
      '\u001b[1;4R',
      '\u001b[?1;4R',
    ]);
  });

  test('Terminal.clear retains the prompt line and disposes markers', () async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 5));
    addTearDown(terminal.dispose);
    await terminal.writeAndWait(
      List<String>.generate(10, (index) => '\n\rtest$index').join(),
    );
    await terminal.writeAndWait('\u001b[31m!');

    final promptLine = terminal.buffer.active.currentLine;
    final cursorX = terminal.buffer.active.cursorX;
    final markers = <TerminalMarker>[
      terminal.registerMarker()!,
      terminal.registerMarker(cursorYOffset: -1)!,
    ];
    var disposalCount = 0;
    for (final marker in markers) {
      marker.onDispose.listen((_) => disposalCount++);
    }
    final scrollEvents = <int>[];
    terminal.onScroll.listen(scrollEvents.add);

    terminal.clear();

    expect(terminal.buffer.active.length, 5);
    expect(terminal.buffer.active.cursorY, 0);
    expect(terminal.buffer.active.cursorX, cursorX);
    expect(terminal.buffer.active.getLine(0), same(promptLine));
    expect(
      terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
      'test9!',
    );
    expect(terminal.buffer.active.getLine(0)!.getCell(5)!.foreground, 1);
    for (var row = 1; row < 5; row++) {
      expect(
        terminal.buffer.active.getLine(row)!.translateToString(trimRight: true),
        isEmpty,
      );
    }
    expect(disposalCount, markers.length);
    expect(markers.every((marker) => marker.isDisposed), isTrue);
    expect(terminal.markers, isEmpty);
    expect(scrollEvents, <int>[0]);

    terminal.clear();
    expect(terminal.buffer.active.getLine(0), same(promptLine));
  });

  test('zero-sized decorations retain xterm registration semantics', () {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final marker = terminal.registerMarker()!;

    final decoration = terminal.registerDecoration(
      marker: marker,
      width: 0,
      height: 0,
    );

    expect(decoration, isNotNull);
    expect((decoration!.width, decoration.height), (0, 0));
    expect(
      () => terminal.registerDecoration(marker: marker, width: -1),
      throwsArgumentError,
    );
    expect(
      () => terminal.registerDecoration(marker: marker, height: -1),
      throwsArgumentError,
    );
  });
}
