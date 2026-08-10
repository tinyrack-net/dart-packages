import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('Default options', () {
    final terminal = _terminal();
    expect(terminal.cols, 80);
    expect(terminal.rows, 24);
  });

  test('write', () async {
    final terminal = _terminal();
    await terminal.writeAndWait('foo');
    await terminal.writeAndWait('bar');
    await terminal.writeAndWait('文');
    _lineEquals(terminal, 0, 'foobar文');
  });

  test('write with callback', () async {
    final terminal = _terminal();
    final done = Completer<void>();
    String? result;
    terminal
      ..write('foo', onParsed: () => result = 'a')
      ..write('bar', onParsed: () => result = '${result}b')
      ..write(
        '文',
        onParsed: () {
          result = '${result}c';
          done.complete();
        },
      );
    await done.future;
    _lineEquals(terminal, 0, 'foobar文');
    expect(result, 'abc');
  });

  test('write - bytes (UTF8)', () async {
    final terminal = _terminal();
    await terminal.writeAndWait(Uint8List.fromList(<int>[102, 111, 111]));
    await terminal.writeAndWait(Uint8List.fromList(<int>[98, 97, 114]));
    await terminal.writeAndWait(Uint8List.fromList(<int>[230, 150, 135]));
    _lineEquals(terminal, 0, 'foobar文');
  });

  test('write - bytes (UTF8) with callback', () async {
    final terminal = _terminal();
    final done = Completer<void>();
    String? result;
    terminal
      ..write(
        Uint8List.fromList(<int>[102, 111, 111]),
        onParsed: () => result = 'A',
      )
      ..write(
        Uint8List.fromList(<int>[98, 97, 114]),
        onParsed: () => result = '${result}B',
      )
      ..write(
        Uint8List.fromList(<int>[230, 150, 135]),
        onParsed: () {
          result = '${result}C';
          done.complete();
        },
      );
    await done.future;
    _lineEquals(terminal, 0, 'foobar文');
    expect(result, 'ABC');
  });

  test('writeln', () async {
    final terminal = _terminal();
    await _writelnAndWait(terminal, 'foo');
    await _writelnAndWait(terminal, 'bar');
    await _writelnAndWait(terminal, '文');
    _lineEquals(terminal, 0, 'foo');
    _lineEquals(terminal, 1, 'bar');
    _lineEquals(terminal, 2, '文');
  });

  test('writeln with callback', () async {
    final terminal = _terminal();
    final done = Completer<void>();
    String? result;
    terminal
      ..writeln('foo', onParsed: () => result = '1')
      ..writeln('bar', onParsed: () => result = '${result}2')
      ..writeln(
        '文',
        onParsed: () {
          result = '${result}3';
          done.complete();
        },
      );
    await done.future;
    _lineEquals(terminal, 0, 'foo');
    _lineEquals(terminal, 1, 'bar');
    _lineEquals(terminal, 2, '文');
    expect(result, '123');
  });

  test('writeln - bytes (UTF8)', () async {
    final terminal = _terminal();
    await _writelnAndWait(terminal, Uint8List.fromList(<int>[102, 111, 111]));
    await _writelnAndWait(terminal, Uint8List.fromList(<int>[98, 97, 114]));
    await _writelnAndWait(terminal, Uint8List.fromList(<int>[230, 150, 135]));
    _lineEquals(terminal, 0, 'foo');
    _lineEquals(terminal, 1, 'bar');
    _lineEquals(terminal, 2, '文');
  });

  test('clear', () async {
    final terminal = _terminal(rows: 5);
    for (var index = 0; index < 10; index++) {
      await terminal.writeAndWait('\n\rtest$index');
    }
    terminal.clear();
    expect(terminal.buffer.active.length, 5);
    _lineEquals(terminal, 0, 'test9');
    for (var index = 1; index < 5; index++) {
      _lineEquals(terminal, index, '');
    }
  });

  test('clearMarkers', () async {
    final terminal = _terminal(rows: 5);
    for (var index = 0; index < 10; index++) {
      await terminal.writeAndWait('\n\rtest$index');
    }
    final markers = <TerminalMarker>[
      terminal.registerMarker(cursorYOffset: 1)!,
      terminal.registerMarker(cursorYOffset: 2)!,
      terminal.registerMarker(cursorYOffset: 3)!,
      terminal.registerMarker(cursorYOffset: 4)!,
    ];
    var disposeCount = 0;
    for (final marker in markers) {
      marker.onDispose.listen((_) => disposeCount++);
    }
    terminal.clear();
    expect(disposeCount, markers.length);
    for (final marker in markers) {
      expect(marker.isDisposed, isTrue);
    }
    expect(terminal.markers, isEmpty);
  });

  test('getter', () {
    final terminal = _terminal();
    expect(terminal.options.lineHeight, 1);
    expect(terminal.options.cursorWidth, 1);
  });

  test('setter', () {
    final terminal = _terminal();
    terminal.options
      ..scrollback = 1
      ..fontSize = 12
      ..fontFamily = 'Arial';
    expect(terminal.options.scrollback, 1);
    expect(terminal.options.fontSize, 12);
    expect(terminal.options.fontFamily, 'Arial');
  });

  test('constructor', () {
    final terminal = Terminal(
      options: TerminalOptions(cols: 5, allowProposedApi: true),
    );
    addTearDown(terminal.dispose);
    final addon = _TrackingAddon();
    terminal.loadAddon(addon);
    expect(addon.activatedColumns, 5);
  });

  test('dispose (addon)', () {
    final terminal = _terminal();
    final addon = _TrackingAddon();
    terminal.loadAddon(addon);
    expect(addon.isDisposed, isFalse);
    addon.dispose();
    expect(addon.isDisposed, isTrue);
  });

  test('dispose (terminal)', () {
    final terminal = _terminal();
    final addon = _TrackingAddon();
    terminal.loadAddon(addon);
    expect(addon.isDisposed, isFalse);
    terminal.dispose();
    expect(addon.isDisposed, isTrue);
  });

  test('onCursorMove', () async {
    final terminal = _terminal();
    var callCount = 0;
    terminal.onCursorMove.listen((_) => callCount++);
    await terminal.writeAndWait('foo');
    expect(callCount, 1);
    await terminal.writeAndWait('bar');
    expect(callCount, 2);
  });

  test('onData', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.onData.listen(calls.add);
    await terminal.writeAndWait('\u001b[5n');
    expect(calls, <String>['\u001b[0n']);
  });

  test('onLineFeed', () async {
    final terminal = _terminal();
    var callCount = 0;
    terminal.onLineFeed.listen((_) => callCount++);
    await _writelnAndWait(terminal, 'foo');
    expect(callCount, 1);
    await _writelnAndWait(terminal, 'bar');
    expect(callCount, 2);
  });

  test('onRender', () async {
    final terminal = _terminal();
    final calls = <List<int>>[];
    terminal.onRender.listen(
      (event) => calls.add(<int>[event.start, event.end]),
    );
    await terminal.writeAndWait('foo');
    expect(calls, <List<int>>[
      <int>[0, 0],
    ]);
    await terminal.writeAndWait('\n\nbar');
    expect(calls, <List<int>>[
      <int>[0, 0],
      <int>[0, 2],
    ]);
  });

  test('onScroll', () async {
    final terminal = _terminal(rows: 5);
    final calls = <int>[];
    terminal.onScroll.listen(calls.add);
    for (var index = 0; index < 4; index++) {
      await _writelnAndWait(terminal, 'foo');
    }
    expect(calls, isEmpty);
    await _writelnAndWait(terminal, 'bar');
    expect(calls, <int>[1]);
    await _writelnAndWait(terminal, 'baz');
    expect(calls, <int>[1, 2]);
  });

  test('onResize', () {
    final terminal = _terminal();
    final calls = <List<int>>[];
    terminal.onResize.listen(
      (event) => calls.add(<int>[event.cols, event.rows]),
    );
    expect(calls, isEmpty);
    terminal.resize(10, 5);
    expect(calls, <List<int>>[
      <int>[10, 5],
    ]);
    terminal.resize(20, 15);
    expect(calls, <List<int>>[
      <int>[10, 5],
      <int>[20, 15],
    ]);
  });

  test('onTitleChange', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.onTitleChange.listen(calls.add);
    expect(calls, isEmpty);
    await terminal.writeAndWait('\u001b]2;foo\u009c');
    expect(calls, <String>['foo']);
  });

  test('onBell', () async {
    final terminal = _terminal();
    final calls = <bool>[];
    terminal.onBell.listen((_) => calls.add(true));
    expect(calls, isEmpty);
    await terminal.writeAndWait('\u0007');
    expect(calls, <bool>[true]);
  });

  test('Proposed API check', () {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    expect(
      () => terminal.unicode,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'You must set the allowProposedApi option to true '
              'to use proposed API',
        ),
      ),
    );
  });

  test('defaults', () {
    final modes = _terminal().modes;
    expect(modes.applicationCursorKeysMode, isFalse);
    expect(modes.applicationKeypadMode, isFalse);
    expect(modes.bracketedPasteMode, isFalse);
    expect(modes.insertMode, isFalse);
    expect(modes.mouseTrackingMode, 'none');
    expect(modes.originMode, isFalse);
    expect(modes.reverseWraparoundMode, isFalse);
    expect(modes.sendFocusMode, isFalse);
    expect(modes.showCursor, isTrue);
    expect(modes.synchronizedOutputMode, isFalse);
    expect(modes.win32InputMode, isFalse);
    expect(modes.wraparoundMode, isTrue);
  });

  test('applicationCursorKeysMode', () async {
    final terminal = _terminal();
    await _expectModeToggle(
      terminal,
      setSequence: '\u001b[?1h',
      resetSequence: '\u001b[?1l',
      value: () => terminal.modes.applicationCursorKeysMode,
    );
  });

  test('applicationKeypadMode', () async {
    final terminal = _terminal();
    await _expectModeToggle(
      terminal,
      setSequence: '\u001b[?66h',
      resetSequence: '\u001b[?66l',
      value: () => terminal.modes.applicationKeypadMode,
    );
  });

  test('bracketedPasteMode', () async {
    final terminal = _terminal();
    await _expectModeToggle(
      terminal,
      setSequence: '\u001b[?2004h',
      resetSequence: '\u001b[?2004l',
      value: () => terminal.modes.bracketedPasteMode,
    );
  });

  test('insertMode', () async {
    final terminal = _terminal();
    await _expectModeToggle(
      terminal,
      setSequence: '\u001b[4h',
      resetSequence: '\u001b[4l',
      value: () => terminal.modes.insertMode,
    );
  });

  test('mouseTrackingMode', () async {
    final terminal = _terminal();
    for (final entry in <(int, String)>[
      (9, 'x10'),
      (1000, 'vt200'),
      (1002, 'drag'),
      (1003, 'any'),
    ]) {
      await terminal.writeAndWait('\u001b[?${entry.$1}h');
      expect(terminal.modes.mouseTrackingMode, entry.$2);
      await terminal.writeAndWait('\u001b[?${entry.$1}l');
      expect(terminal.modes.mouseTrackingMode, 'none');
    }
  });

  test('originMode', () async {
    final terminal = _terminal();
    await _expectModeToggle(
      terminal,
      setSequence: '\u001b[?6h',
      resetSequence: '\u001b[?6l',
      value: () => terminal.modes.originMode,
    );
  });

  test('reverseWraparoundMode', () async {
    final terminal = _terminal();
    await _expectModeToggle(
      terminal,
      setSequence: '\u001b[?45h',
      resetSequence: '\u001b[?45l',
      value: () => terminal.modes.reverseWraparoundMode,
    );
  });

  test('sendFocusMode', () async {
    final terminal = _terminal();
    await _expectModeToggle(
      terminal,
      setSequence: '\u001b[?1004h',
      resetSequence: '\u001b[?1004l',
      value: () => terminal.modes.sendFocusMode,
    );
  });

  test('wraparoundMode', () async {
    final terminal = _terminal();
    await terminal.writeAndWait('\u001b[?7h');
    expect(terminal.modes.wraparoundMode, isTrue);
    await terminal.writeAndWait('\u001b[?7l');
    expect(terminal.modes.wraparoundMode, isFalse);
  });

  test('dispose', () {
    final terminal = _terminal()..dispose();
    expect(terminal.isDisposed, isTrue);
  });

  test('cursorX, cursorY', () async {
    final terminal = _terminal(rows: 5, cols: 5);
    expect(terminal.buffer.active.cursorX, 0);
    expect(terminal.buffer.active.cursorY, 0);
    await terminal.writeAndWait('foo');
    expect(terminal.buffer.active.cursorX, 3);
    expect(terminal.buffer.active.cursorY, 0);
    await terminal.writeAndWait('\n');
    expect(terminal.buffer.active.cursorX, 3);
    expect(terminal.buffer.active.cursorY, 1);
    await terminal.writeAndWait('\r');
    expect(terminal.buffer.active.cursorX, 0);
    expect(terminal.buffer.active.cursorY, 1);
    await terminal.writeAndWait('abcde');
    expect(terminal.buffer.active.cursorX, 5);
    expect(terminal.buffer.active.cursorY, 1);
    await terminal.writeAndWait('\n\r\n\n\n\n\n');
    expect(terminal.buffer.active.cursorX, 0);
    expect(terminal.buffer.active.cursorY, 4);
  });

  test('viewportY', () async {
    final terminal = _terminal(rows: 5);
    expect(terminal.buffer.active.viewportY, 0);
    await terminal.writeAndWait('\n\n\n\n');
    expect(terminal.buffer.active.viewportY, 0);
    await terminal.writeAndWait('\n');
    expect(terminal.buffer.active.viewportY, 1);
    await terminal.writeAndWait('\n\n\n\n');
    expect(terminal.buffer.active.viewportY, 5);
    terminal.scrollLines(-1);
    expect(terminal.buffer.active.viewportY, 4);
    terminal.scrollToTop();
    expect(terminal.buffer.active.viewportY, 0);
  });

  test('baseY', () async {
    final terminal = _terminal(rows: 5);
    expect(terminal.buffer.active.baseY, 0);
    await terminal.writeAndWait('\n\n\n\n');
    expect(terminal.buffer.active.baseY, 0);
    await terminal.writeAndWait('\n');
    expect(terminal.buffer.active.baseY, 1);
    await terminal.writeAndWait('\n\n\n\n');
    expect(terminal.buffer.active.baseY, 5);
    terminal.scrollLines(-1);
    expect(terminal.buffer.active.baseY, 5);
    terminal.scrollToTop();
    expect(terminal.buffer.active.baseY, 5);
  });

  test('length', () async {
    final terminal = _terminal(rows: 5);
    expect(terminal.buffer.active.length, 5);
    await terminal.writeAndWait('\n\n\n\n');
    expect(terminal.buffer.active.length, 5);
    await terminal.writeAndWait('\n');
    expect(terminal.buffer.active.length, 6);
    await terminal.writeAndWait('\n\n\n\n');
    expect(terminal.buffer.active.length, 10);
  });

  test('invalid index', () {
    final terminal = _terminal(rows: 5);
    expect(terminal.buffer.active.getLine(-1), isNull);
    expect(terminal.buffer.active.getLine(5), isNull);
  });

  test('isWrapped', () async {
    final terminal = _terminal(cols: 5);
    expect(terminal.buffer.active.getLine(0)!.isWrapped, isFalse);
    expect(terminal.buffer.active.getLine(1)!.isWrapped, isFalse);
    await terminal.writeAndWait('abcde');
    expect(terminal.buffer.active.getLine(0)!.isWrapped, isFalse);
    expect(terminal.buffer.active.getLine(1)!.isWrapped, isFalse);
    await terminal.writeAndWait('f');
    expect(terminal.buffer.active.getLine(0)!.isWrapped, isFalse);
    expect(terminal.buffer.active.getLine(1)!.isWrapped, isTrue);
  });

  test('translateToString', () async {
    final terminal = _terminal(cols: 5);
    final line = terminal.buffer.active.getLine(0)!;
    expect(line.translateToString(), '     ');
    expect(line.translateToString(trimRight: true), '');
    await terminal.writeAndWait('foo');
    expect(line.translateToString(), 'foo  ');
    expect(line.translateToString(trimRight: true), 'foo');
    await terminal.writeAndWait('bar');
    expect(line.translateToString(), 'fooba');
    expect(line.translateToString(trimRight: true), 'fooba');
    expect(
      terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
      'r',
    );
    expect(line.translateToString(startColumn: 1), 'ooba');
    expect(line.translateToString(startColumn: 1, endColumn: 3), 'oo');
  });

  test('getCell', () async {
    final terminal = _terminal(cols: 5);
    final line = terminal.buffer.active.getLine(0)!;
    expect(line.getCell(-1), isNull);
    expect(line.getCell(5), isNull);
    expect(line.getCell(0)!.chars, '');
    expect(line.getCell(0)!.width, 1);
    await terminal.writeAndWait('a文');
    expect(line.getCell(0)!.chars, 'a');
    expect(line.getCell(0)!.width, 1);
    expect(line.getCell(1)!.chars, '文');
    expect(line.getCell(1)!.width, 2);
    expect(line.getCell(2)!.chars, '');
    expect(line.getCell(2)!.width, 0);
  });

  test('active, normal, alternate', () async {
    final terminal = _terminal(cols: 5);
    expect(terminal.buffer.active.type, TerminalBufferType.normal);
    expect(terminal.buffer.normal.type, TerminalBufferType.normal);
    expect(terminal.buffer.alternate.type, TerminalBufferType.alternate);
    await terminal.writeAndWait('norm ');
    _bufferLineEquals(terminal.buffer.active, 0, 'norm ');
    _bufferLineEquals(terminal.buffer.normal, 0, 'norm ');
    expect(terminal.buffer.alternate.getLine(0), isNull);
    await terminal.writeAndWait('\u001b[?47h\r');
    expect(terminal.buffer.active.type, TerminalBufferType.alternate);
    _bufferLineEquals(terminal.buffer.active, 0, '     ');
    await terminal.writeAndWait('alt  ');
    _bufferLineEquals(terminal.buffer.active, 0, 'alt  ');
    _bufferLineEquals(terminal.buffer.normal, 0, 'norm ');
    _bufferLineEquals(terminal.buffer.alternate, 0, 'alt  ');
    await terminal.writeAndWait('\u001b[?47l\r');
    expect(terminal.buffer.active.type, TerminalBufferType.normal);
    _bufferLineEquals(terminal.buffer.active, 0, 'norm ');
    _bufferLineEquals(terminal.buffer.normal, 0, 'norm ');
    expect(terminal.buffer.alternate.getLine(0), isNull);
  });

  test('xterm HeadlessTerminal 44', () async {
    final terminal = _terminal(cols: 5);
    await terminal.writeAndWait('\u001b[?47h');
    final marker = terminal.registerMarker();
    expect(terminal.buffer.active.type, TerminalBufferType.alternate);
    expect(terminal.markers, <TerminalMarker?>[marker]);
  });
}

Terminal _terminal({int rows = 24, int cols = 80}) {
  final terminal = Terminal(
    options: TerminalOptions(allowProposedApi: true, rows: rows, cols: cols),
  );
  addTearDown(terminal.dispose);
  return terminal;
}

Future<void> _writelnAndWait(Terminal terminal, Object data) {
  final completer = Completer<void>();
  terminal.writeln(data, onParsed: completer.complete);
  return completer.future;
}

void _lineEquals(Terminal terminal, int line, String expected) {
  expect(
    terminal.buffer.active.getLine(line)!.translateToString(trimRight: true),
    expected,
  );
}

void _bufferLineEquals(TerminalBuffer buffer, int line, String expected) {
  expect(buffer.getLine(line)!.translateToString(), expected);
}

Future<void> _expectModeToggle(
  Terminal terminal, {
  required String setSequence,
  required String resetSequence,
  required bool Function() value,
}) async {
  await terminal.writeAndWait(setSequence);
  expect(value(), isTrue);
  await terminal.writeAndWait(resetSequence);
  expect(value(), isFalse);
}

final class _TrackingAddon extends TerminalAddon {
  int? activatedColumns;

  @override
  void activate(Terminal terminal) {
    activatedColumns = terminal.cols;
  }
}
