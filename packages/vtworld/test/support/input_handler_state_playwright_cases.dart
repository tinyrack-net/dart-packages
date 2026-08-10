import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerStatePlaywrightCase(String name) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  final data = <String>[];
  terminal.onData.listen(data.add);
  if (name.startsWith('should save the absolute')) {
    terminal.resize(10, 2);
    await terminal.writeAndWait('1\n\r2\n\r3\n\r4\n\r5\x1b7\x1b[?47h');
    terminal.resize(10, 4);
    await terminal.writeAndWait('\x1b[?47l\x1b8');
    return expect(
      (terminal.buffer.active.cursorX, terminal.buffer.active.cursorY),
      (1, 3),
    );
  }
  if (name.contains('Request ANSI mode')) {
    await terminal.writeAndWait(
      '\x1b[4h\x1b[4\u0024p\x1b[4l\x1b[4\u0024p\x1b[20h\x1b[20\u0024p',
    );
    return expect(data, <String>[
      '\x1b[4;1\u0024y',
      '\x1b[4;2\u0024y',
      '\x1b[20;1\u0024y',
    ]);
  }
  if (name.contains('Request DEC private mode')) {
    await terminal.writeAndWait('\x1b[?1h\x1b[?1\u0024p\x1b[?1l\x1b[?1\u0024p');
    return expect(data, <String>['\x1b[?1;1\u0024y', '\x1b[?1;2\u0024y']);
  }
  if (name.contains('SM: Set Mode')) {
    await terminal.writeAndWait('\x1b[4h\x1b[20h');
    expect(terminal.modes.insertMode, isTrue);
    return expect(terminal.options.convertEol, isTrue);
  }
  if (name.contains('RM: Reset Mode')) {
    await terminal.writeAndWait('\x1b[4h\x1b[20h\x1b[4l\x1b[20l');
    expect(terminal.modes.insertMode, isFalse);
    return expect(terminal.options.convertEol, isFalse);
  }
  if (name.contains('Soft terminal reset')) {
    await terminal.writeAndWait('\x1b[4h\x1b[?6h\x1b[3;5r\x1b[!p');
    expect(terminal.modes.insertMode, isFalse);
    expect(terminal.modes.originMode, isFalse);
    return expect(
      (terminal.modes.scrollTop, terminal.modes.scrollBottom),
      (0, terminal.rows - 1),
    );
  }
  if (name.contains('Set cursor style')) return _cursorStyle(terminal);
  if (name.contains('protection attribute')) {
    await terminal.writeAndWait('\x1b[1"qPROT\x1b[2"qopen\x1b[1;1H\x1b[?2K');
    return expect(
      terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
      'PROT',
    );
  }
  if (name.contains('Scrolling Region')) {
    await terminal.writeAndWait('\x1b[2;4r');
    expect((terminal.modes.scrollTop, terminal.modes.scrollBottom), (1, 3));
    await terminal.writeAndWait('\x1b[r');
    return expect(
      (terminal.modes.scrollTop, terminal.modes.scrollBottom),
      (0, terminal.rows - 1),
    );
  }
  if (name.startsWith('CSI s -') || name.startsWith('CSI u -')) {
    final position = name.startsWith('CSI s') ? '\x1b[3;4H' : '\x1b[4;6H';
    await terminal.writeAndWait('$position\x1b[s\x1b[1;1H\x1b[u');
    return expect((
      terminal.buffer.active.cursorX,
      terminal.buffer.active.cursorY,
    ), name.startsWith('CSI s') ? (3, 2) : (5, 3));
  }
  throw StateError('unhandled state Playwright case: $name');
}

Future<void> _cursorStyle(Terminal terminal) async {
  final expected = <(int, TerminalCursorStyle, bool)>[
    (1, TerminalCursorStyle.block, true),
    (2, TerminalCursorStyle.block, false),
    (3, TerminalCursorStyle.underline, true),
    (4, TerminalCursorStyle.underline, false),
    (5, TerminalCursorStyle.bar, true),
    (6, TerminalCursorStyle.bar, false),
  ];
  for (final (value, style, blink) in expected) {
    await terminal.writeAndWait('\x1b[$value q');
    expect(
      (terminal.modes.cursorStyle, terminal.modes.cursorBlink),
      (style, blink),
    );
  }
  await terminal.writeAndWait('\x1b[0 q');
  expect(terminal.modes.cursorStyle, terminal.options.cursorStyle);
  expect(terminal.modes.cursorBlink, terminal.options.cursorBlink);
}
