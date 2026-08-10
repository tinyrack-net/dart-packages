import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyBrowserTerminalCase(String name) async {
  if (name.startsWith('Terminal events ')) return _eventCase(name);
  if (name.startsWith('Terminal clear ')) return _clearCase(name);
  if (name.startsWith('Terminal paste ')) return _pasteCase(name);
  if (name.startsWith('Terminal scroll ')) return _scrollCase(name);
  if (name.startsWith('Terminal Third level shift ')) {
    return _thirdLevelShiftCase(name);
  }
  if (name.startsWith('Terminal insert mode ')) return _insertCase(name);
  if (name.startsWith('Terminal Windows Pty ')) return _windowsPtyCase(name);
  if (name.startsWith('Terminal marker lifecycle ')) {
    return _markerCase(name);
  }
  if (name.startsWith('Terminal options ')) return _optionsCase(name);
  if (name.startsWith('Terminal attachCustomKeyEventHandler ')) {
    return _customKeyCase(name);
  }
  if (name == 'Terminal convertEol setting') return _convertEolCase();
  if (name == 'Terminal should not mutate the options parameter') {
    final options = TerminalOptions();
    _terminal(options: options).resize(1000, 24);
    expect((options.cols, options.rows), (80, 24));
    return;
  }
  throw StateError('Unknown pinned browser Terminal parity case: $name');
}

Terminal _terminal({TerminalOptions? options}) {
  final terminal = Terminal(options: options);
  addTearDown(terminal.dispose);
  return terminal;
}

Future<void> _eventCase(String name) async {
  final terminal = _terminal();
  if (name.endsWith('onData evnet')) {
    final values = <String>[];
    terminal.onData.listen(values.add);
    terminal.input('fake');
    expect(values, <String>['fake']);
  } else if (name.endsWith('onCursorMove event')) {
    var count = 0;
    terminal.onCursorMove.listen((_) => count++);
    await terminal.writeAndWait('foo');
    expect(count, 1);
  } else if (name.endsWith('onLineFeed event')) {
    var count = 0;
    terminal.onLineFeed.listen((_) => count++);
    await terminal.writeAndWait('\n');
    expect(count, 1);
  } else if (name.endsWith('scrollback is created')) {
    final values = <int>[];
    terminal.onScroll.listen(values.add);
    await terminal.writeAndWait(List<String>.filled(24, '\n').join());
    expect(values, isNotEmpty);
  } else if (name.endsWith('scrollback is cleared')) {
    await terminal.writeAndWait(List<String>.filled(24, '\n').join());
    final values = <int>[];
    terminal.onScroll.listen(values.add);
    terminal.clear();
    expect(values, <int>[0]);
  } else if (name.contains('key event after a key')) {
    final values = <TerminalKeyEvent>[];
    terminal.onKey.listen(values.add);
    const event = TerminalKeyEvent(key: '\r');
    terminal.handleKeyEvent(event);
    expect(values, <TerminalKeyEvent>[event]);
  } else if (name.endsWith('onResize event')) {
    final values = <TerminalResizeEvent>[];
    terminal.onResize.listen(values.add);
    terminal.resize(2, 2);
    expect((values.single.cols, values.single.rows), (2, 2));
  } else if (name.endsWith('onScroll event')) {
    final values = <int>[];
    terminal.onScroll.listen(values.add);
    await terminal.writeAndWait(List<String>.filled(25, '\n').join());
    expect(values, isNotEmpty);
  } else if (name.endsWith('onTitleChange event')) {
    final values = <String>[];
    terminal.onTitleChange.listen(values.add);
    await terminal.writeAndWait('\u001b]2;title\u0007');
    expect(values, <String>['title']);
  } else if (name.endsWith('onBell event')) {
    var count = 0;
    terminal.onBell.listen((_) => count++);
    await terminal.writeAndWait('\u0007');
    expect(count, 1);
  } else {
    throw StateError(name);
  }
}

Future<void> _clearCase(String name) async {
  final terminal = _terminal(options: TerminalOptions(cols: 10, rows: 5));
  if (name.endsWith('larger than rows')) {
    await terminal.writeAndWait(List<String>.filled(10, 'test\n').join());
  } else {
    await terminal.writeAndWait('prompt');
  }
  final prompt = terminal.buffer.active.currentLine.translateToString();
  terminal.clear();
  if (name.endsWith('cleared twice')) terminal.clear();
  final buffer = terminal.buffer.active;
  expect((buffer.cursorY, buffer.baseY, terminal.viewportY), (0, 0, 0));
  expect(buffer.length, terminal.rows);
  expect(buffer.getLine(0)!.translateToString(), prompt);
  for (var row = 1; row < terminal.rows; row++) {
    expect(buffer.getLine(row)!.translateToString(trimRight: true), isEmpty);
  }
}

Future<void> _pasteCase(String name) async {
  final terminal = _terminal();
  final values = <String>[];
  terminal.onData.listen(values.add);
  if (name.endsWith('fire data event')) {
    terminal.paste('foo');
    expect(values, <String>['foo']);
  } else if (name.contains('sanitize')) {
    terminal.paste('\r\nfoo\nbar\r');
    expect(values, <String>['\rfoo\rbar\r']);
  } else {
    await terminal.writeAndWait('\u001b[?2004h');
    terminal.paste('foo');
    expect(values, <String>['\u001b[200~foo\u001b[201~']);
  }
}

Future<void> _scrollCase(String name) async {
  if (name.contains('scroll() function')) return _bufferScrollCase(name);
  final terminal = _terminal(options: TerminalOptions(cols: 10, rows: 5));
  await terminal.writeAndWait(List<String>.filled(16, 'test\r\n').join());
  final bottom = terminal.buffer.active.baseY;
  if (name.contains('custom keydown handler')) {
    terminal
      ..attachCustomKeyEventHandler((_) => false)
      ..scrollLines(-1);
    final before = terminal.viewportY;
    if (terminal.handleKeyEvent(const TerminalKeyEvent(key: 'a'))) {
      terminal.input('a');
    }
    expect(terminal.viewportY, before);
  } else if (name.contains('modifier-only')) {
    terminal.scrollLines(-1);
    final before = terminal.viewportY;
    terminal.handleKeyEvent(
      const TerminalKeyEvent(key: 'Control', control: true),
    );
    expect(terminal.viewportY, before);
  } else if (name.contains('key is pressed')) {
    terminal
      ..scrollToTop()
      ..input('a');
    expect(terminal.viewportY, bottom);
  } else if (name.contains('scrollLines')) {
    if (name.endsWith('single line')) {
      terminal.scrollLines(-1);
      expect(terminal.viewportY, bottom - 1);
      terminal.scrollLines(1);
      expect(terminal.viewportY, bottom);
    } else if (name.endsWith('multiple lines')) {
      terminal.scrollLines(-5);
      expect(terminal.viewportY, bottom - 5);
      terminal.scrollLines(5);
      expect(terminal.viewportY, bottom);
    } else {
      terminal
        ..scrollLines(1)
        ..scrollToTop()
        ..scrollLines(-1);
      expect(terminal.viewportY, 0);
    }
  } else if (name.contains('scrollPages')) {
    final pages = name.contains('multiple pages') ? 2 : 1;
    terminal.scrollPages(-pages);
    expect(terminal.viewportY, bottom - (terminal.rows - 1) * pages);
    terminal.scrollPages(pages);
    expect(terminal.viewportY, bottom);
  } else if (name.contains('scrollToTop')) {
    terminal.scrollToTop();
    expect(terminal.viewportY, 0);
  } else if (name.contains('scrollToBottom')) {
    terminal
      ..scrollToTop()
      ..scrollToBottom();
    expect(terminal.viewportY, bottom);
  } else if (name.contains('scrollToLine')) {
    if (name.contains('boundary')) {
      terminal.scrollToLine(-1);
      expect(terminal.viewportY, 0);
      terminal.scrollToLine(bottom + 1);
      expect(terminal.viewportY, bottom);
    } else {
      terminal.scrollToLine(3);
      expect(terminal.viewportY, 3);
    }
  } else {
    throw StateError(name);
  }
}

Future<void> _bufferScrollCase(String name) async {
  final scrollback = name.contains('scrollback === 0') ? 0 : 1000;
  final terminal = _terminal(
    options: TerminalOptions(cols: 5, rows: 5, scrollback: scrollback),
  );
  final buffer = terminal.buffer.active;
  for (var row = 0; row < 5; row++) {
    buffer
        .getLine(row)!
        .setCell(0, String.fromCharCode(97 + row), 1, TerminalCellAttributes());
  }
  final hasTop =
      name.contains('scrollTop set') ||
      name.contains('scrollTop and scrollBottom');
  final hasBottom = name.contains('scrollBottom set');
  final top = hasTop ? 1 : 0;
  final bottom = hasBottom ? 3 : 4;
  buffer.scroll(TerminalCellAttributes(), top: top, bottom: bottom);
  final createsScrollback = scrollback > 0 && top == 0 && bottom == 4;
  expect(buffer.length, createsScrollback ? 6 : 5);
  if (top == 1) {
    expect(buffer.getLine(0)!.getCell(0)!.chars, 'a');
    expect(buffer.getLine(1)!.getCell(0)!.chars, 'c');
  } else if (bottom == 3) {
    expect(
      List<String>.generate(5, (row) => buffer.getLine(row)!.getCell(0)!.chars),
      <String>['b', 'c', 'd', '', 'e'],
    );
  } else if (scrollback == 0) {
    expect(buffer.getLine(0)!.getCell(0)!.chars, 'b');
  } else {
    expect(buffer.getLine(0)!.getCell(0)!.chars, 'a');
    expect(buffer.getLine(5)!.translateToString(trimRight: true), isEmpty);
  }
}

void _thirdLevelShiftCase(String name) {
  final isMac = name.contains('Mac OS') || name.contains('macOptionIsMeta');
  final isWindows = name.contains('MS Windows');
  final macOptionIsMeta = name.contains('macOptionIsMeta');
  final arrow = name.contains('arrow keys');
  final emit = name.contains('emit key');
  final allowed = isTerminalThirdLevelShift(
    isMac: isMac,
    isWindows: isWindows,
    macOptionIsMeta: macOptionIsMeta,
    altKey: true,
    ctrlKey: isWindows,
    metaKey: false,
    altGraph: false,
    isKeyPress: emit,
    keyCode: arrow
        ? 37
        : emit
        ? 64
        : 81,
  );
  expect(allowed, !arrow && !macOptionIsMeta);
  if (emit) {
    expect(String.fromCharCode(64), '@');
  }
}

Future<void> _insertCase(String name) async {
  final terminal = _terminal(options: TerminalOptions(rows: 2));
  if (name.endsWith('halfwidth - all')) {
    await terminal.writeAndWait(List<String>.filled(8, '0123456789').join());
    await terminal.writeAndWait('\u001b[1;11H\u001b[4habcde');
    final line = terminal.buffer.active.getLine(0)!;
    expect(line.getCell(10)!.chars, 'a');
    expect(line.getCell(14)!.chars, 'e');
    expect(line.getCell(15)!.chars, '0');
    expect(line.getCell(79)!.chars, '4');
  } else if (name.endsWith('fullwidth - insert')) {
    await terminal.writeAndWait(List<String>.filled(8, '0123456789').join());
    await terminal.writeAndWait('\u001b[1;11H\u001b[4h￥￥￥');
    final line = terminal.buffer.active.getLine(0)!;
    expect((line.getCell(10)!.chars, line.getCell(11)!.width), ('￥', 0));
    expect((line.getCell(14)!.chars, line.getCell(15)!.width), ('￥', 0));
    expect(line.getCell(79)!.chars, '3');
  } else {
    await terminal.writeAndWait(List<String>.filled(40, '￥').join());
    await terminal.writeAndWait('\u001b[1;11H\u001b[4hab');
    final line = terminal.buffer.active.getLine(0)!;
    expect(line.getCell(10)!.chars, 'a');
    expect(line.getCell(11)!.chars, 'b');
    expect(line.getCell(12)!.chars, '￥');
    expect(line.getCell(79)!.chars, isEmpty);
  }
}

Future<void> _windowsPtyCase(String name) async {
  final sequence = name.endsWith('after a LF')
      ? 'aaaaaaaaaa\n\raaaaaaaaa\n\raaaaaaaaa'
      : 'aaaaaaaaaa\u001b[2;1Haaaaaaaaa\u001b[3;1Haaaaaaaaa';
  final regular = _terminal(options: TerminalOptions(cols: 10, rows: 5));
  final windows = _terminal(
    options: TerminalOptions(
      cols: 10,
      rows: 5,
      windowsPty: const TerminalWindowsPtyOptions(
        backend: 'conpty',
        buildNumber: 19000,
      ),
    ),
  );
  await regular.writeAndWait(sequence);
  await windows.writeAndWait(sequence);
  expect(regular.buffer.active.getLine(1)!.isWrapped, isFalse);
  expect(windows.buffer.active.getLine(1)!.isWrapped, isTrue);
}

Future<void> _markerCase(String name) async {
  final terminal = _terminal(
    options: TerminalOptions(cols: 10, rows: 5, scrollback: 1),
  );
  final markers = <TerminalMarker>[];
  for (var row = 0; row < 5; row++) {
    markers.add(terminal.registerMarker()!);
    if (row < 4) await terminal.writeAndWait('$row\r\n');
  }
  final disposed = <TerminalMarker>[];
  for (final marker in markers) {
    marker.onDispose.listen((_) => disposed.add(marker));
  }
  if (name.endsWith('initial')) {
    expect(markers.map((marker) => marker.line), <int>[0, 1, 2, 3, 4]);
  } else if (name.endsWith('normal trim off the top')) {
    await terminal.writeAndWait('\n\n\n');
    expect(disposed.take(2), <TerminalMarker>[markers[0], markers[1]]);
  } else if (name.endsWith('on DL')) {
    await terminal.writeAndWait('\u001b[3;1H\u001b[2M');
    expect(disposed, <TerminalMarker>[markers[2], markers[3]]);
  } else if (name.endsWith('on IL')) {
    await terminal.writeAndWait('\u001b[3;1H\u001b[2L');
    expect(disposed, <TerminalMarker>[markers[4], markers[3]]);
  } else {
    terminal.resize(10, 2);
    expect(disposed, <TerminalMarker>[markers[0], markers[1]]);
  }
}

void _optionsCase(String name) {
  final terminal = _terminal();
  if (name.endsWith('get options')) {
    expect((terminal.options.cols, terminal.options.rows), (80, 24));
  } else {
    terminal.resize(40, 20);
    expect((terminal.cols, terminal.rows), (40, 20));
  }
}

Future<void> _customKeyCase(String name) async {
  final terminal = _terminal();
  const event = TerminalKeyEvent(key: 'M');
  terminal.attachCustomKeyEventHandler((value) => value.key == 'M');
  expect(terminal.handleKeyEvent(event), isTrue);
  terminal.attachCustomKeyEventHandler((value) => value.key != 'M');
  expect(terminal.handleKeyEvent(event), isFalse);
  if (name.contains('alive after reset')) {
    await terminal.writeAndWait('\u001bc');
    expect(terminal.handleKeyEvent(event), isFalse);
  }
}

Future<void> _convertEolCase() async {
  final regular = _terminal(options: TerminalOptions(cols: 15, rows: 10));
  final converting = _terminal(
    options: TerminalOptions(cols: 15, rows: 10, convertEol: true),
  );
  await regular.writeAndWait('Hello\nWorld');
  await converting.writeAndWait(Uint8List.fromList('Hello\nWorld'.codeUnits));
  final regularFirst = regular.buffer.active.getLine(0)!;
  final regularSecond = regular.buffer.active.getLine(1)!;
  expect(regularFirst.translateToString(), 'Hello          ');
  expect(regularSecond.translateToString(), '     World     ');
  expect(regularFirst.translateToString(trimRight: true), 'Hello');
  expect(regularSecond.translateToString(trimRight: true), '     World');
  final convertingFirst = converting.buffer.active.getLine(0)!;
  final convertingSecond = converting.buffer.active.getLine(1)!;
  expect(convertingFirst.translateToString(), 'Hello          ');
  expect(convertingSecond.translateToString(), 'World          ');
  expect(convertingFirst.translateToString(trimRight: true), 'Hello');
  expect(convertingSecond.translateToString(trimRight: true), 'World');
}
