import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler OSC colors', () {
    test('4: query color events', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);
      await terminal.writeAndWait('\x1b]4;0;?;123;?\x07');
      expect(reports.length, 2);
      expect(reports[0], startsWith('\x1b]4;0;rgb:'));
      expect(reports[1], startsWith('\x1b]4;123;rgb:'));
    });

    test('4: set color events', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b]4;0;rgb:01/02/03;123;#aabbcc\x07'
        '\x1b]4;0;rgb:aa/bb/cc;123;#001122\x07',
      );
      expect(terminal.colorOverrides.indexed[0], 0xaabbcc);
      expect(terminal.colorOverrides.indexed[123], 0x001122);
    });

    test('4: should ignore invalid values', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b]4;0;rgb:aa/bb/cc;45;rgb:1/22/333;123;#001122\x07',
      );
      expect(terminal.colorOverrides.indexed, <int, int>{
        0: 0xaabbcc,
        123: 0x001122,
      });
    });

    test('104: restore events', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b]4;0;#010203;43;#040506\x07');
      await terminal.writeAndWait('\x1b]104;0;43\x07');
      expect(terminal.colorOverrides.indexed, isEmpty);
      await terminal.writeAndWait(
        '\x1b]4;0;#010203;43;#040506\x07\x1b]104\x07',
      );
      expect(terminal.colorOverrides.indexed, isEmpty);
    });

    test('10: FG set & query events', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);
      await terminal.writeAndWait(
        '\x1b]10;?;?;?;?\x07'
        '\x1b]10;rgb:aa/bb/cc;#001122;rgb:12/34/56\x07',
      );
      expect(reports.length, 3);
      expect(terminal.colorOverrides.foreground, 0xaabbcc);
      expect(terminal.colorOverrides.background, 0x001122);
      expect(terminal.colorOverrides.cursor, 0x123456);
    });

    test('110: restore FG color', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b]10;#010203\x07\x1b]110\x07');
      expect(terminal.colorOverrides.foreground, isNull);
    });

    test('11: BG set & query events', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);
      await terminal.writeAndWait(
        '\x1b]11;?;?;?;?\x07\x1b]11;#001122;rgb:12/34/56\x07',
      );
      expect(reports.length, 2);
      expect(terminal.colorOverrides.background, 0x001122);
      expect(terminal.colorOverrides.cursor, 0x123456);
    });

    test('111: restore BG color', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b]11;#010203\x07\x1b]111\x07');
      expect(terminal.colorOverrides.background, isNull);
    });

    test('12: cursor color set & query events', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);
      await terminal.writeAndWait(
        '\x1b]12;?;?;?;?\x07\x1b]12;rgb:01/02/03\x07\x1b]12;#aabbcc\x07',
      );
      expect(reports.length, 1);
      expect(terminal.colorOverrides.cursor, 0xaabbcc);
    });

    test('112: restore cursor color', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b]12;#010203\x07\x1b]112\x07');
      expect(terminal.colorOverrides.cursor, isNull);
    });
  });
}

Terminal _terminal() => Terminal(
  options: TerminalOptions(
    theme: const TerminalColorTheme(
      foreground: '#010203',
      background: '#040506',
      cursor: '#070809',
    ),
  ),
);
