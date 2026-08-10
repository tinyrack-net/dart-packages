import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler text attributes', () {
    test('bold', () => _verifyToggle('\x1b[1m', '\x1b[22m', (a) => a.bold));
    test('dim', () => _verifyToggle('\x1b[2m', '\x1b[22m', (a) => a.dim));
    test('italic', () => _verifyToggle('\x1b[3m', '\x1b[23m', (a) => a.italic));
    test(
      'underline',
      () => _verifyToggle(
        '\x1b[4m',
        '\x1b[24m',
        (a) => a.underline != TerminalUnderlineStyle.none,
      ),
    );
    test('blink', () => _verifyToggle('\x1b[5m', '\x1b[25m', (a) => a.blink));
    test(
      'inverse',
      () => _verifyToggle('\x1b[7m', '\x1b[27m', (a) => a.inverse),
    );
    test(
      'invisible',
      () => _verifyToggle('\x1b[8m', '\x1b[28m', (a) => a.invisible),
    );
    test(
      'strikethrough',
      () => _verifyToggle('\x1b[9m', '\x1b[29m', (a) => a.strikethrough),
    );

    test('SGR 221 resets bold only (kitty)', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[1;2m');
      expect(terminal.currentAttributes.bold, isTrue);
      expect(terminal.currentAttributes.dim, isTrue);
      await terminal.writeAndWait('\x1b[221m');
      expect(terminal.currentAttributes.bold, isFalse);
      expect(terminal.currentAttributes.dim, isTrue);
    });

    test('SGR 222 resets faint only (kitty)', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[1;2m');
      expect(terminal.currentAttributes.bold, isTrue);
      expect(terminal.currentAttributes.dim, isTrue);
      await terminal.writeAndWait('\x1b[222m');
      expect(terminal.currentAttributes.bold, isTrue);
      expect(terminal.currentAttributes.dim, isFalse);
    });

    test('colormode palette 16', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      _expectDefaultColors(terminal);
      for (var value = 0; value < 8; value++) {
        await terminal.writeAndWait('\x1b[${value + 30};${value + 40}m');
        _expectColors(terminal, TerminalColorMode.palette, value);
      }
      await terminal.writeAndWait('\x1b[39;49m');
      _expectDefaultColors(terminal);
    });

    test('colormode palette 256', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      _expectDefaultColors(terminal);
      for (var value = 0; value < 256; value++) {
        await terminal.writeAndWait('\x1b[38;5;$value;48;5;${value}m');
        _expectColors(terminal, TerminalColorMode.palette, value);
      }
      await terminal.writeAndWait('\x1b[39;49m');
      _expectDefaultColors(terminal);
    });

    test('colormode RGB', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      _expectDefaultColors(terminal);
      await terminal.writeAndWait('\x1b[38;2;1;2;3;48;2;4;5;6m');
      expect(terminal.currentAttributes.foreground.mode, TerminalColorMode.rgb);
      expect(terminal.currentAttributes.foreground.value, 0x010203);
      expect(terminal.currentAttributes.background.mode, TerminalColorMode.rgb);
      expect(terminal.currentAttributes.background.value, 0x040506);
      await terminal.writeAndWait('\x1b[39;49m');
      _expectDefaultColors(terminal);
    });

    test('colormode transition RGB to 256', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b[38;2;1;2;3;48;2;4;5;6m\x1b[38;5;255;48;5;255m',
      );
      _expectColors(terminal, TerminalColorMode.palette, 255);
    });

    test('colormode transition RGB to 16', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[38;2;1;2;3;48;2;4;5;6m\x1b[37;47m');
      _expectColors(terminal, TerminalColorMode.palette, 7);
    });

    test('colormode transition 16 to 256', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[37;47m\x1b[38;5;255;48;5;255m');
      _expectColors(terminal, TerminalColorMode.palette, 255);
    });

    test('colormode transition 256 to 16', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[38;5;255;48;5;255m\x1b[37;47m');
      _expectColors(terminal, TerminalColorMode.palette, 7);
    });

    test('should zero missing RGB values', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[38;2;1;2;3m\x1b[38;2;5m');
      expect(terminal.currentAttributes.foreground.mode, TerminalColorMode.rgb);
      expect(terminal.currentAttributes.foreground.value, 0x050000);
    });
  });
}

Future<void> _verifyToggle(
  String enable,
  String disable,
  bool Function(TerminalCellAttributes attributes) read,
) async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait(enable);
    expect(read(terminal.currentAttributes), isTrue);
    await terminal.writeAndWait(disable);
    expect(read(terminal.currentAttributes), isFalse);
  } finally {
    terminal.dispose();
  }
}

void _expectDefaultColors(Terminal terminal) {
  expect(
    terminal.currentAttributes.foreground.mode,
    TerminalColorMode.defaultColor,
  );
  expect(
    terminal.currentAttributes.background.mode,
    TerminalColorMode.defaultColor,
  );
}

void _expectColors(Terminal terminal, TerminalColorMode mode, int value) {
  expect(terminal.currentAttributes.foreground.mode, mode);
  expect(terminal.currentAttributes.foreground.value, value);
  expect(terminal.currentAttributes.background.mode, mode);
  expect(terminal.currentAttributes.background.value, value);
}
