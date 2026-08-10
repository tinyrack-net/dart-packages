import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler DECRQM', () {
    test('ANSI 2 keyboard action mode', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      expect(await fixture.query('\x1b[2\u0024p'), '\x1b[2;4\u0024y');
    });

    test('ANSI 4 insert mode', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      expect(await fixture.query('\x1b[4\u0024p'), '\x1b[4;2\u0024y');
      expect(await fixture.query('\x1b[4h\x1b[4\u0024p'), '\x1b[4;1\u0024y');
      expect(await fixture.query('\x1b[4l\x1b[4\u0024p'), '\x1b[4;2\u0024y');
    });

    test('ANSI 12 send receive', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      expect(await fixture.query('\x1b[12\u0024p'), '\x1b[12;3\u0024y');
    });

    test('ANSI 20 newline mode', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      expect(await fixture.query('\x1b[20\u0024p'), '\x1b[20;2\u0024y');
      expect(await fixture.query('\x1b[20h\x1b[20\u0024p'), '\x1b[20;1\u0024y');
      expect(await fixture.query('\x1b[20l\x1b[20\u0024p'), '\x1b[20;2\u0024y');
    });

    test('ANSI unknown', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      expect(await fixture.query('\x1b[1234\u0024p'), '\x1b[1234;0\u0024y');
    });

    test('DEC privates with set reset semantic', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      const initiallyReset = <int>[
        1,
        6,
        9,
        45,
        66,
        1000,
        1002,
        1003,
        1004,
        1006,
        1016,
        47,
        1047,
        1049,
        2004,
        2026,
      ];
      for (final mode in initiallyReset) {
        expect(
          await fixture.query('\x1b[?$mode\u0024p'),
          '\x1b[?$mode;2\u0024y',
          reason: 'initial private mode $mode',
        );
        expect(
          await fixture.query('\x1b[?${mode}h\x1b[?$mode\u0024p'),
          '\x1b[?$mode;1\u0024y',
          reason: 'set private mode $mode',
        );
        expect(
          await fixture.query('\x1b[?${mode}l\x1b[?$mode\u0024p'),
          '\x1b[?$mode;2\u0024y',
          reason: 'reset private mode $mode',
        );
      }
      for (final mode in const <int>[7, 25]) {
        expect(
          await fixture.query('\x1b[?$mode\u0024p'),
          '\x1b[?$mode;1\u0024y',
          reason: 'initial private mode $mode',
        );
        expect(
          await fixture.query('\x1b[?${mode}l\x1b[?$mode\u0024p'),
          '\x1b[?$mode;2\u0024y',
          reason: 'reset private mode $mode',
        );
        expect(
          await fixture.query('\x1b[?${mode}h\x1b[?$mode\u0024p'),
          '\x1b[?$mode;1\u0024y',
          reason: 'set private mode $mode',
        );
      }
    });

    test('DEC privates quirks', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      expect(await fixture.query('\x1b[?12\u0024p'), '\x1b[?12;2\u0024y');
      expect(
        await fixture.query('\x1b[?12h\x1b[?12\u0024p'),
        '\x1b[?12;2\u0024y',
      );
      fixture.terminal.options.quirks = const TerminalQuirks(
        allowSetCursorBlink: true,
      );
      expect(
        await fixture.query('\x1b[?12h\x1b[?12\u0024p'),
        '\x1b[?12;1\u0024y',
      );
      expect(
        await fixture.query('\x1b[?12l\x1b[?12\u0024p'),
        '\x1b[?12;2\u0024y',
      );
    });

    test('DEC privates perma modes', () async {
      final fixture = _ReportFixture();
      addTearDown(fixture.dispose);
      const expected = <int, int>{3: 0, 8: 3, 67: 4, 1005: 4, 1015: 4, 1048: 1};
      for (final entry in expected.entries) {
        expect(
          await fixture.query('\x1b[?${entry.key}\u0024p'),
          '\x1b[?${entry.key};${entry.value}\u0024y',
        );
      }
    });
  });
}

final class _ReportFixture {
  _ReportFixture() {
    _listener = terminal.onData.listen(_reports.add);
  }

  final Terminal terminal = Terminal();
  final List<String> _reports = <String>[];
  late final Disposable _listener;

  Future<String> query(String data) async {
    _reports.clear();
    await terminal.writeAndWait(data);
    expect(_reports, isNotEmpty);
    return _reports.last;
  }

  void dispose() {
    _listener.dispose();
    terminal.dispose();
  }
}
