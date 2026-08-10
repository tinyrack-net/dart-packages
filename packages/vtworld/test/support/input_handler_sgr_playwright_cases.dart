import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerSgrPlaywrightCase(String name) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  if (name.startsWith('Ps = 0 ')) {
    await terminal.writeAndWait('\u001b[1;3;4;5;7;8;9m#\u001b[0m@');
    final first = terminal.buffer.active.getLine(0)!.getCell(0)!;
    expect(<bool>[
      first.isBold,
      first.isItalic,
      first.isUnderline,
      first.isBlink,
      first.isInverse,
      first.isInvisible,
      first.isStrikethrough,
    ], everyElement(isTrue));
    expect(
      terminal.buffer.active.getLine(0)!.getCell(1)!.isAttributeDefault,
      isTrue,
    );
    return;
  }
  final numeric = RegExp(r'^Ps = (\d+) ').firstMatch(name);
  if (numeric != null) {
    final code = int.parse(numeric.group(1)!);
    if (_setAttributes.contains(code)) {
      await terminal.writeAndWait('\u001b[${code}m#');
      expect(_attribute(terminal, 0, code), isTrue);
      return;
    }
    final setCode = _resetAttributes[code];
    if (setCode != null) {
      if (code == 22) {
        await terminal.writeAndWait('\u001b[1;2m#\u001b[22m@');
        final line = terminal.buffer.active.getLine(0)!;
        expect(
          <bool>[line.getCell(0)!.isBold, line.getCell(0)!.isDim],
          [true, true],
        );
        expect(
          <bool>[line.getCell(1)!.isBold, line.getCell(1)!.isDim],
          [false, false],
        );
        return;
      }
      await terminal.writeAndWait('\u001b[${setCode}m#\u001b[${code}m@');
      expect(_attribute(terminal, 0, setCode), isTrue);
      expect(_attribute(terminal, 1, setCode), isFalse);
      return;
    }
    if (code == 39 || code == 49) {
      final foreground = code == 39;
      await terminal.writeAndWait(
        foreground ? '\u001b[31m#\u001b[39m@' : '\u001b[41m#\u001b[49m@',
      );
      final line = terminal.buffer.active.getLine(0)!;
      final first = line.getCell(0)!;
      final second = line.getCell(1)!;
      expect(
        foreground ? first.isForegroundPalette : first.isBackgroundPalette,
        isTrue,
      );
      expect(foreground ? first.foreground : first.background, 1);
      expect(
        foreground ? second.isForegroundDefault : second.isBackgroundDefault,
        isTrue,
      );
      return;
    }
    if (_isPaletteCode(code)) {
      await terminal.writeAndWait('\u001b[${code}m#');
      final cell = terminal.buffer.active.getLine(0)!.getCell(0)!;
      final foreground = code < 40 || code >= 90 && code < 100;
      expect(
        foreground ? cell.isForegroundPalette : cell.isBackgroundPalette,
        isTrue,
      );
      expect(
        foreground ? cell.foreground : cell.background,
        _paletteIndex(code),
      );
      return;
    }
  }
  if (name.startsWith('Ps = 38:2:')) {
    return _extendedColor(
      terminal,
      '\u001b[38:2::171:205:239m#',
      true,
      0xabcdef,
    );
  }
  if (name.startsWith('Ps = 38:5:')) {
    return _extendedColor(terminal, '\u001b[38:5:123m#', true, 123);
  }
  if (name.startsWith('Ps = 48:2:')) {
    return _extendedColor(terminal, '\u001b[48:2::18:52:86m#', false, 0x123456);
  }
  if (name.startsWith('Ps = 48:5:')) {
    return _extendedColor(terminal, '\u001b[48:5:200m#', false, 200);
  }
  if (name.startsWith('Ps = 38;2;')) {
    return _extendedColor(
      terminal,
      '\u001b[38;2;171;205;239m#',
      true,
      0xabcdef,
    );
  }
  if (name.startsWith('Ps = 48;2;')) {
    return _extendedColor(terminal, '\u001b[48;2;18;52;86m#', false, 0x123456);
  }
  throw StateError('Unknown pinned InputHandler SGR parity case: $name');
}

const Set<int> _setAttributes = <int>{1, 2, 3, 4, 5, 7, 8, 9, 21};
const Map<int, int> _resetAttributes = <int, int>{
  22: 1,
  23: 3,
  24: 4,
  25: 5,
  27: 7,
  28: 8,
  29: 9,
};

bool _attribute(Terminal terminal, int column, int code) {
  final cell = terminal.buffer.active.getLine(0)!.getCell(column)!;
  return switch (code) {
    1 => cell.isBold,
    2 => cell.isDim,
    3 => cell.isItalic,
    4 || 21 => cell.isUnderline,
    5 => cell.isBlink,
    7 => cell.isInverse,
    8 => cell.isInvisible,
    9 => cell.isStrikethrough,
    _ => throw ArgumentError.value(code, 'code'),
  };
}

bool _isPaletteCode(int code) =>
    code >= 30 && code <= 37 ||
    code >= 40 && code <= 47 ||
    code >= 90 && code <= 97 ||
    code >= 100 && code <= 107;

int _paletteIndex(int code) => switch (code) {
  >= 30 && <= 37 => code - 30,
  >= 40 && <= 47 => code - 40,
  >= 90 && <= 97 => code - 90 + 8,
  _ => code - 100 + 8,
};

Future<void> _extendedColor(
  Terminal terminal,
  String sequence,
  bool foreground,
  int expected,
) async {
  await terminal.writeAndWait(sequence);
  final cell = terminal.buffer.active.getLine(0)!.getCell(0)!;
  final rgb = expected > 255;
  expect(
    foreground
        ? rgb
              ? cell.isForegroundRgb
              : cell.isForegroundPalette
        : rgb
        ? cell.isBackgroundRgb
        : cell.isBackgroundPalette,
    isTrue,
  );
  expect(foreground ? cell.foreground : cell.background, expected);
}
