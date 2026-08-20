import 'dart:async';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

/// [Terminal.resize] flushes the write buffer before it changes the geometry,
/// and a resize fires on any frame — including one where the parser is
/// suspended on an asynchronous handler. That flush used to re-enter the
/// parser, which refuses re-entry, so the resize threw and the chunk the
/// parser was holding was abandoned.
void main() {
  test(
    'resize during an async parser handler keeps the queued output',
    () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final gate = Completer<bool>();
      final handled = <String>[];
      terminal.parser.registerOscHandler(1337, (data) {
        handled.add(data);
        return gate.future;
      });

      terminal.write('\x1b]1337;hold\x07');
      // Let the write buffer reach the handler and suspend there.
      await Future<void>.delayed(Duration.zero);
      expect(handled, <String>[
        'hold',
      ], reason: 'the handler should be awaiting');

      terminal
        ..write('queued')
        ..resize(40, 10);
      expect(terminal.cols, 40);
      expect(terminal.rows, 10);

      gate.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        _line(terminal, 0),
        contains('queued'),
        reason: 'output queued behind the handler must still be parsed',
      );
    },
  );

  test('resize without a pending handler still flushes before resizing', () {
    final terminal = Terminal();
    addTearDown(terminal.dispose);

    terminal
      ..write('flushed')
      ..resize(40, 10);

    expect(_line(terminal, 0), contains('flushed'));
    expect(terminal.cols, 40);
  });

  test(
    'resize flushes more than one queued chunk without re-entering',
    () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      // A PTY delivers output in whatever chunks it arrives in, so a resize
      // can land on a frame with several already queued. Parsing is
      // asynchronous even with no handler registered, so the flush suspends on
      // the first chunk and cannot resume: it holds the isolate, and no
      // microtask can run until it returns. Draining the rest in the same loop
      // re-enters a parser that refuses re-entry.
      terminal
        ..write('first ')
        ..write('second')
        ..resize(40, 10);

      expect(terminal.cols, 40);
      expect(terminal.rows, 10);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        _line(terminal, 0),
        'first second',
        reason: 'both chunks must reach the parser, in order',
      );
    },
  );
}

String _line(Terminal terminal, int row) =>
    terminal.buffer.active.getLine(row)?.translateToString(trimRight: true) ??
    '';
