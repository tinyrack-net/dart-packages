import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler DECSCA and DECSED/DECSEL', () {
    test('default is unprotected', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      await terminal.writeAndWait('some text\x1b[?2K');
      expect(_lines(terminal), <String>['', '']);
      await terminal.writeAndWait('some text\x1b[?2J');
      expect(_lines(terminal), <String>['', '']);
    });

    test('DECSCA 1 with DECSEL', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      await terminal.writeAndWait('###\x1b[1"qlineerase\x1b[0"q***\x1b[?2K');
      expect(_lines(terminal), <String>['   lineerase', '']);
      await terminal.writeAndWait('\x1b[2K');
      expect(_lines(terminal), <String>['', '']);
    });

    test('DECSCA 1 with DECSED', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      await terminal.writeAndWait('###\x1b[1"qdisplayerase\x1b[0"q***\x1b[?2J');
      expect(_lines(terminal), <String>['   displayerase', '']);
      await terminal.writeAndWait('\x1b[2J');
      expect(_lines(terminal), <String>['', '']);
    });

    test('DECRQSS reports correct DECSCA state', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);

      await terminal.writeAndWait(
        '\x1bP\u0024q"q\x1b\\'
        '\x1b[1"q\x1bP\u0024q"q\x1b\\'
        '\x1b[2"q\x1bP\u0024q"q\x1b\\',
      );

      expect(reports, <String>[
        '\x1bP1\u0024r0"q\x1b\\',
        '\x1bP1\u0024r1"q\x1b\\',
        '\x1bP1\u0024r0"q\x1b\\',
      ]);
    });
  });
}

List<String> _lines(Terminal terminal) => <String>[
  for (var row = 0; row < 2; row++)
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true),
];
