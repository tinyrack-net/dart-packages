import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerDecModePlaywrightCase(
  String name, {
  required bool enabled,
}) async {
  final code = _modeCode(name);
  final terminal = Terminal(
    options: TerminalOptions(
      quirks: const TerminalQuirks(allowSetCursorBlink: true),
      windowOptions: const TerminalWindowOptions(setWinLines: true),
    ),
  );
  addTearDown(terminal.dispose);
  if (code == 2 && enabled) return _charsetCase(terminal);
  if (code == 3) return _columnModeCase(terminal, enabled);
  if (code == 6) return _originModeCase(terminal, enabled);
  if (code == 7) return _wrapModeCase(terminal, enabled);
  if (code == 47 || code == 1047) {
    return _alternateBufferCase(terminal, code, enabled);
  }
  if (code == 1048) return _saveCursorCase(terminal, enabled);
  if (code == 1049) return _saveCursorAlternateCase(terminal, enabled);
  if (code == 1004) return _focusCase(terminal, enabled);
  if (code == 1005 || code == 1015) {
    return _removedMouseEncodingCase(terminal, code, enabled);
  }
  final getter = _modeGetter(code);
  if (getter != null) {
    if (!enabled) await terminal.writeAndWait('\u001b[?${code}h');
    await terminal.writeAndWait('\u001b[?$code${enabled ? 'h' : 'l'}');
    expect(getter(terminal), enabled);
    return;
  }
  final before = _snapshot(terminal);
  await terminal.writeAndWait('\u001b[?$code${enabled ? 'h' : 'l'}');
  expect(_snapshot(terminal), before);
}

int _modeCode(String name) {
  final match = RegExp(r'^[A-Z][a-z] = ([\d ]+)').firstMatch(name);
  if (match == null) throw StateError('DEC mode number is missing: $name');
  return int.parse(match.group(1)!.replaceAll(' ', ''));
}

Future<void> _charsetCase(Terminal terminal) async {
  await terminal.writeAndWait('\u001b(0q\u001b[?2hq');
  expect(
    terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
    '─q',
  );
}

Future<void> _columnModeCase(Terminal terminal, bool enabled) async {
  if (!enabled) await terminal.writeAndWait('\u001b[?3h');
  await terminal.writeAndWait('\u001b[?3${enabled ? 'h' : 'l'}');
  expect(terminal.cols, enabled ? 132 : 80);
  expect(
    (terminal.buffer.active.cursorX, terminal.buffer.active.cursorY),
    (0, 0),
  );
}

Future<void> _originModeCase(Terminal terminal, bool enabled) async {
  if (!enabled) await terminal.writeAndWait('\u001b[?6h');
  await terminal.writeAndWait('\u001b[?6${enabled ? 'h' : 'l'}');
  expect(terminal.modes.originMode, enabled);
  expect(
    (terminal.buffer.active.cursorX, terminal.buffer.active.cursorY),
    (0, 0),
  );
  if (enabled) {
    await terminal.writeAndWait('\u001b[2;3r\u001b[1;1HX');
    expect(
      terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
      'X',
    );
  }
}

Future<void> _wrapModeCase(Terminal terminal, bool enabled) async {
  terminal.resize(5, 2);
  await terminal.writeAndWait('\u001b[?7${enabled ? 'h' : 'l'}12345X');
  expect(terminal.modes.wraparoundMode, enabled);
  expect(
    terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
    enabled ? '12345' : '1234X',
  );
  if (enabled) {
    expect(
      terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
      'X',
    );
  }
}

Future<void> _alternateBufferCase(
  Terminal terminal,
  int code,
  bool enabled,
) async {
  await terminal.writeAndWait('main');
  if (!enabled) await terminal.writeAndWait('\u001b[?${code}h');
  await terminal.writeAndWait('\u001b[?$code${enabled ? 'h' : 'l'}');
  expect(
    terminal.buffer.active.type,
    enabled ? TerminalBufferType.alternate : TerminalBufferType.normal,
  );
  if (enabled) {
    expect(
      terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
      isEmpty,
    );
  } else {
    expect(
      terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
      'main',
    );
  }
}

Future<void> _saveCursorCase(Terminal terminal, bool _) async {
  await terminal.writeAndWait(
    '\u001b[4;5H\u001b[?1048h\u001b[1;1H\u001b[?1048l',
  );
  expect(
    (terminal.buffer.active.cursorX, terminal.buffer.active.cursorY),
    (4, 3),
  );
}

Future<void> _saveCursorAlternateCase(Terminal terminal, bool _) async {
  await terminal.writeAndWait(
    'main\u001b[4;6H\u001b[?1049h\u001b[Halt\u001b[?1049l',
  );
  expect(terminal.buffer.active.type, TerminalBufferType.normal);
  expect(
    terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
    'main',
  );
  expect(
    (terminal.buffer.active.cursorX, terminal.buffer.active.cursorY),
    (5, 3),
  );
}

Future<void> _focusCase(Terminal terminal, bool enabled) async {
  if (!enabled) await terminal.writeAndWait('\u001b[?1004h');
  await terminal.writeAndWait('\u001b[?1004${enabled ? 'h' : 'l'}');
  expect(terminal.modes.sendFocusMode, enabled);
  final data = <String>[];
  terminal.onData.listen(data.add);
  terminal
    ..reportFocus(focused: true)
    ..reportFocus(focused: false);
  expect(data, enabled ? <String>['\u001b[I', '\u001b[O'] : isEmpty);
}

Future<void> _removedMouseEncodingCase(
  Terminal terminal,
  int code,
  bool enabled,
) async {
  await terminal.writeAndWait('\u001b[?1006h');
  expect(terminal.modes.mouseEncoding, 'SGR');
  await terminal.writeAndWait('\u001b[?$code${enabled ? 'h' : 'l'}');
  expect(terminal.modes.mouseEncoding, 'SGR');
}

bool Function(Terminal)? _modeGetter(int code) => switch (code) {
  1 => (terminal) => terminal.modes.applicationCursorKeysMode,
  7 => (terminal) => terminal.modes.wraparoundMode,
  9 => (terminal) => terminal.modes.mouseProtocol == 'X10',
  12 => (terminal) => terminal.options.cursorBlink,
  25 => (terminal) => terminal.modes.showCursor,
  45 => (terminal) => terminal.modes.reverseWraparoundMode,
  66 => (terminal) => terminal.modes.applicationKeypadMode,
  1000 => (terminal) => terminal.modes.mouseProtocol == 'VT200',
  1002 => (terminal) => terminal.modes.mouseProtocol == 'DRAG',
  1003 => (terminal) => terminal.modes.mouseProtocol == 'ANY',
  1006 => (terminal) => terminal.modes.mouseEncoding == 'SGR',
  1016 => (terminal) => terminal.modes.mouseEncoding == 'SGR_PIXELS',
  2004 => (terminal) => terminal.modes.bracketedPasteMode,
  _ => null,
};

List<Object> _snapshot(Terminal terminal) => <Object>[
  terminal.modes.applicationCursorKeysMode,
  terminal.modes.applicationKeypadMode,
  terminal.modes.bracketedPasteMode,
  terminal.modes.insertMode,
  terminal.modes.originMode,
  terminal.modes.reverseWraparoundMode,
  terminal.modes.sendFocusMode,
  terminal.modes.showCursor,
  terminal.modes.wraparoundMode,
  terminal.options.cursorBlink,
  terminal.cols,
  terminal.rows,
  terminal.buffer.active.type,
  terminal.modes.mouseProtocol,
  terminal.modes.mouseEncoding,
];
