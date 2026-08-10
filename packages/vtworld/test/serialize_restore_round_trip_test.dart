import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

/// Builds a terminal with the serializer attached.
({Terminal terminal, SerializeAddon serialize}) _terminal({
  int columns = 40,
  int rows = 6,
  int scrollback = 20,
}) {
  final terminal = Terminal(
    options: TerminalOptions(cols: columns, rows: rows, scrollback: scrollback),
  );
  final serialize = SerializeAddon();
  terminal.loadAddon(serialize);
  addTearDown(terminal.dispose);
  return (terminal: terminal, serialize: serialize);
}

String _screen(Terminal terminal) {
  final buffer = terminal.buffer.active;
  return <String>[
    for (var line = 0; line < buffer.length; line += 1)
      buffer.translateBufferLineToString(line, trimRight: true),
  ].join('\n');
}

void main() {
  group('serialize restores a session into a fresh terminal', () {
    test('a full-screen program keeps its alternate buffer', () async {
      final origin = _terminal();
      // What a full-screen program does: scroll some shell history, switch to
      // the alternate buffer, paint it, and leave the cursor inside it.
      await origin.terminal.writeAndWait(
        'shell-line-one\r\nshell-line-two\r\n',
      );
      await origin.terminal.writeAndWait(
        '\u001b[?1049h\u001b[H\u001b[2Jeditor-first-row'
        '\u001b[3;5Heditor-marker',
      );
      expect(
        identical(
          origin.terminal.buffer.active,
          origin.terminal.buffer.alternate,
        ),
        isTrue,
        reason: 'the fixture must actually be on the alternate buffer',
      );

      final restored = _terminal();
      await restored.terminal.writeAndWait(origin.serialize.serialize());

      // The restored client is genuinely in the alternate buffer, not merely
      // painted with its contents: leaving it has to uncover the shell history
      // underneath, the way it would have on the original terminal.
      expect(
        identical(
          restored.terminal.buffer.active,
          restored.terminal.buffer.alternate,
        ),
        isTrue,
      );
      expect(_screen(restored.terminal), _screen(origin.terminal));

      await origin.terminal.writeAndWait('\u001b[?1049l');
      await restored.terminal.writeAndWait('\u001b[?1049l');
      expect(_screen(restored.terminal), contains('shell-line-two'));
      expect(_screen(restored.terminal), _screen(origin.terminal));
    });

    test(
      'serializing the restored terminal reproduces the same ANSI',
      () async {
        final origin = _terminal();
        await origin.terminal.writeAndWait(
          'plain\r\n\u001b[31mred\u001b[0m \u001b[1mbold\u001b[0m\r\n'
          '\u001b[?1049h\u001b[H\u001b[44mblue background\u001b[0m',
        );
        final ansi = origin.serialize.serialize();

        final restored = _terminal();
        await restored.terminal.writeAndWait(ansi);

        // Idempotence is the contract a server depends on: a snapshot describes
        // a state completely, so re-serializing what it produced cannot drift.
        expect(restored.serialize.serialize(), ansi);
      },
    );

    test('private modes survive the round trip', () async {
      final origin = _terminal();
      await origin.terminal.writeAndWait(
        '\u001b[?1h\u001b[?2004h\u001b[?45h\u001b[?6h',
      );

      final restored = _terminal();
      await restored.terminal.writeAndWait(origin.serialize.serialize());

      final modes = restored.terminal.modes;
      expect(modes.applicationCursorKeysMode, isTrue);
      expect(modes.bracketedPasteMode, isTrue);
      expect(modes.reverseWraparoundMode, isTrue);
      expect(modes.originMode, isTrue);
    });

    test('scrollback is restored up to the requested depth', () async {
      final origin = _terminal();
      for (var line = 0; line < 12; line += 1) {
        await origin.terminal.writeAndWait('history-$line\r\n');
      }

      final restored = _terminal();
      await restored.terminal.writeAndWait(
        origin.serialize.serialize(
          options: const TerminalSerializeOptions(scrollback: 3),
        ),
      );

      final screen = _screen(restored.terminal);
      expect(screen, contains('history-11'));
      expect(screen, isNot(contains('history-0')));
    });
  });

  // A server feeding a mirror needs to know when the grid corresponds to the
  // bytes it has fed, so it can label a snapshot with the last byte it
  // includes. Parsing is asynchronous here — a custom sequence handler may
  // return a future — so that guarantee is `writeAndWait`, not a synchronous
  // write. These pin the properties the server depends on.
  group('writeAndWait', () {
    test('completes only after the payload has been parsed', () async {
      final origin = _terminal();

      final parsed = origin.terminal.writeAndWait('parsed');
      expect(
        origin.terminal.buffer.active.translateBufferLineToString(
          0,
          trimRight: true,
        ),
        isEmpty,
        reason: 'parsing must not have finished before the future did',
      );

      await parsed;
      expect(
        origin.terminal.buffer.active.translateBufferLineToString(
          0,
          trimRight: true,
        ),
        'parsed',
      );
    });

    test('parses after work already queued by write', () async {
      final origin = _terminal();
      origin.terminal.write('queued ');

      await origin.terminal.writeAndWait('awaited');

      expect(
        origin.terminal.buffer.active.translateBufferLineToString(
          0,
          trimRight: true,
        ),
        'queued awaited',
      );
    });

    test('rejects a payload that is neither text nor bytes', () {
      final origin = _terminal();

      expect(() => origin.terminal.writeAndWait(42), throwsArgumentError);
    });

    test('reports a disposed terminal instead of silently dropping data', () {
      final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2))
        ..dispose();

      expect(() => terminal.writeAndWait('ignored'), throwsStateError);
    });
  });
}
