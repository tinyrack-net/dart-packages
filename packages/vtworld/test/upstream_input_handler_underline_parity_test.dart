import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler extended underline style support', () {
    test('4 | 24', () => _verifyUnderline('4', TerminalUnderlineStyle.single));
    test(
      '21 | 24',
      () => _verifyUnderline('21', TerminalUnderlineStyle.double),
    );
    test(
      '4:1 | 4:0',
      () => _verifyExtended('1', TerminalUnderlineStyle.single),
    );
    test(
      '4:2 | 4:0',
      () => _verifyExtended('2', TerminalUnderlineStyle.double),
    );
    test('4:3 | 4:0', () => _verifyExtended('3', TerminalUnderlineStyle.curly));
    test(
      '4:4 | 4:0',
      () => _verifyExtended('4', TerminalUnderlineStyle.dotted),
    );
    test(
      '4:5 | 4:0',
      () => _verifyExtended('5', TerminalUnderlineStyle.dashed),
    );

    test('4:x --> 4 should revert to single underline', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[4:5m');
      expect(
        terminal.currentAttributes.underline,
        TerminalUnderlineStyle.dashed,
      );
      await terminal.writeAndWait('\x1b[4m');
      expect(
        terminal.currentAttributes.underline,
        TerminalUnderlineStyle.single,
      );
    });
  });

  group('InputHandler underline colors', () {
    test('defaults to FG color', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('A\x1b[30mB\x1b[38;510mC\x1b[38;2;1;2;3mD');
      for (var column = 0; column < 4; column++) {
        final cell = terminal.buffer.active.getLine(0)!.getCell(column)!;
        expect(cell.underlineColorMode, cell.foregroundMode);
        expect(cell.underlineColorValue, cell.foreground);
      }
    });

    test('correctly sets P256/RGB colors', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[4;58;5;123mA\x1b[58;2::1:2:3mB');
      final line = terminal.buffer.active.getLine(0)!;
      expect(
        line.getCell(0)!.underlineColor,
        const TerminalCellColor.palette(123),
      );
      expect(
        line.getCell(1)!.underlineColor,
        const TerminalCellColor.rgb(1, 2, 3),
      );
    });

    test('P256/RGB persistence', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b[4;58;5;123mab'
        '\x1b[4:0mc'
        '\x1b[4;58;2::1:2:3md'
        '\x1b[24m',
      );
      final line = terminal.buffer.active.getLine(0)!;
      expect(
        line.getCell(0)!.underlineColor,
        const TerminalCellColor.palette(123),
      );
      expect(
        line.getCell(1)!.underlineColor,
        const TerminalCellColor.palette(123),
      );
      expect(
        line.getCell(2)!.underlineColorMode,
        TerminalColorMode.defaultColor,
      );
      expect(
        line.getCell(3)!.underlineColor,
        const TerminalCellColor.rgb(1, 2, 3),
      );
    });
  });
}

Future<void> _verifyUnderline(
  String enable,
  TerminalUnderlineStyle expected,
) async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('\x1b[${enable}m');
    expect(terminal.currentAttributes.underline, expected);
    await terminal.writeAndWait('\x1b[24m');
    expect(terminal.currentAttributes.underline, TerminalUnderlineStyle.none);
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyExtended(
  String style,
  TerminalUnderlineStyle expected,
) async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('\x1b[4:${style}m');
    expect(terminal.currentAttributes.underline, expected);
    await terminal.writeAndWait('\x1b[4:0m');
    expect(terminal.currentAttributes.underline, TerminalUnderlineStyle.none);
    await terminal.writeAndWait('\x1b[4:${style}m\x1b[24m');
    expect(terminal.currentAttributes.underline, TerminalUnderlineStyle.none);
  } finally {
    terminal.dispose();
  }
}
