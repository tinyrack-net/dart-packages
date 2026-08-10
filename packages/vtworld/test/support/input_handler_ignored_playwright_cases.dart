import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerIgnoredPlaywrightCase(String name) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  final data = <String>[];
  terminal.onData.listen(data.add);
  await terminal.writeAndWait('abc');
  if (name.contains('XTHIMOUSE')) {
    await terminal.writeAndWait('\x1b[1;1;1;1;1T');
    expect(_line(terminal, 0), isEmpty);
    expect(_line(terminal, 1), 'abc');
    expect(data, isEmpty);
    return;
  }
  if (name.contains('DECSLRM')) {
    await terminal.writeAndWait('\x1b[2;79s');
    expect(terminal.buffer.active.savedCursorX, 3);
    expect(terminal.buffer.active.savedCursorY, 0);
    expect(data, isEmpty);
    return;
  }
  final before = _snapshot(terminal);
  await terminal.writeAndWait(_sequence(name));
  expect(_snapshot(terminal), before);
  expect(data, isEmpty);
  await terminal.writeAndWait('Z');
  final cell = terminal.buffer.active.getLine(0)!.getCell(3)!;
  expect(cell.isAttributeDefault, isTrue);
}

String _sequence(String name) {
  if (name.contains('DECSWBV')) return '\x1b[1 t';
  if (name.contains('DECSMBV')) return '\x1b[1 u';
  if (name.contains('XTRMTITLE')) return '\x1b[>1T';
  if (name.contains('alias for CSI # {')) return '\x1b[#p';
  if (name.contains('XTPUSHSGR')) return '\x1b[#{';
  if (name.startsWith('CSI # }')) return '\x1b[#}';
  if (name.startsWith('CSI # q')) return '\x1b[#q';
  if (name.contains('DECLL')) return '\x1b[1q';
  if (name.contains('Media Copy, DEC')) return '\x1b[?1i';
  if (name.contains('Media Copy')) return '\x1b[1i';
  if (name.contains('DECSNLS')) return '\x1b[24*|';
  if (name.contains('DECERA')) return '\x1b[1;1;2;2\u0024z';
  if (name.contains('DECSACE')) return '\x1b[1*x';
  if (name.contains('DECSASD')) return '\x1b[1\u0024}';
  if (name.contains('DECRARA')) return '\x1b[1;1;2;2;1\u0024t';
  if (name.contains('DECRQLP')) return "\x1b[1'|";
  if (name.contains('DECFRA')) return '\x1b[65;1;1;2;2\u0024x';
  if (name.contains('DECSLE')) return "\x1b[1'{";
  if (name.contains('DECEFR')) return "\x1b[1;1;2;2'w";
  if (name.contains('XTREPORTSGR')) return '\x1b[1;1;2;2#|';
  if (name.contains('XTRESTORE')) return '\x1b[?1r';
  if (name.contains('Set/reset key modifier')) return '\x1b[>1;1m';
  if (name.contains('Query key modifier')) return '\x1b[?1m';
  if (name.contains('Disable key modifier')) return '\x1b[>1n';
  if (name.contains('DECRQCRA')) return '\x1b[1;1;1;2;2;1*y';
  if (name.contains('XTPUSHCOLORS')) return '\x1b[#P';
  if (name.contains('XTPOPCOLORS')) return '\x1b[#Q';
  if (name.contains('XTREPORTCOLORS')) return '\x1b[#R';
  if (name.contains('DECSERA')) return '\x1b[1;1;2;2\u0024{';
  if (name.contains('DECSCPP')) return '\x1b[80\u0024|';
  if (name.contains('XTSMTITLE')) return '\x1b[>1t';
  if (name.contains('DECRQPSR')) return '\x1b[1\u0024w';
  if (name.contains('DECSLRM')) return '\x1b[2;79s';
  if (name.contains('DECELR')) return "\x1b[1;0'z";
  if (name.contains('DECSSDT')) return '\x1b[1\u0024~';
  if (name.contains('XTSAVE')) return '\x1b[?1s';
  if (name.contains('XTCHECKSUM')) return '\x1b[1#y';
  if (name.contains('XTSHIFTESCAPE')) return '\x1b[>1s';
  if (name.contains('DECCARA')) return '\x1b[1;1;2;2;1\u0024r';
  if (name.contains('DECREQTPARM')) return '\x1b[1x';
  if (name.contains('DECSCL')) return '\x1b[62;1"p';
  if (name.contains('DECCRA')) return '\x1b[1;1;2;2;1;1;1;1\u0024v';
  if (name.contains('XTSMPOINTER')) return '\x1b[>1p';
  throw StateError('missing ignored InputHandler sequence: $name');
}

List<Object> _snapshot(Terminal terminal) => <Object>[
  _line(terminal, 0),
  terminal.buffer.active.cursorX,
  terminal.buffer.active.cursorY,
  terminal.buffer.active.savedCursorX,
  terminal.buffer.active.savedCursorY,
  terminal.cols,
  terminal.rows,
  terminal.modes.insertMode,
  terminal.modes.originMode,
  terminal.modes.wraparoundMode,
  terminal.modes.applicationCursorKeysMode,
  terminal.modes.applicationKeypadMode,
  terminal.modes.bracketedPasteMode,
  terminal.modes.mouseProtocol,
  terminal.modes.mouseEncoding,
  terminal.options.convertEol,
  terminal.options.cursorStyle,
  terminal.options.cursorBlink,
  terminal.colorOverrides.indexed.toString(),
];

String _line(Terminal terminal, int row) => terminal.buffer.active
    .getLine(terminal.buffer.active.baseY + row)!
    .translateToString(trimRight: true);
