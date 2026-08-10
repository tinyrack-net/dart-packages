import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm BufferLine 00', () {
    final line = TerminalBufferLine(3);
    expect(line.length, 3);
    expect(line.translateToString(), '   ');
    expect(line.isWrapped, isFalse);
  });

  test('xterm BufferLine 01', () {
    final line = _line('abc')..isWrapped = true;
    final clone = line.copy();
    line.setCell(0, 'z', 1, TerminalCellAttributes());
    expect(clone.translateToString(), 'abc');
    expect(clone.isWrapped, isTrue);
  });

  test('xterm BufferLine 02', () {
    final source = _line('abc')..isWrapped = true;
    final target = _line('12345')..copyFrom(source);
    source.setCell(0, 'z', 1, TerminalCellAttributes());
    expect(target.translateToString(), 'abc');
    expect(target.length, 3);
    expect(target.isWrapped, isTrue);
  });

  test('xterm BufferLine 03', () {
    final line = _line('abc')..fill(TerminalCellAttributes(bold: true));
    expect(line.translateToString(), '   ');
    expect(line.getCell(0)!.isBold, isTrue);
  });

  test('xterm BufferLine 04', () {
    expect(TerminalBufferLine(5).getTrimmedLength(), 0);
  });

  test('xterm BufferLine 05', () {
    final line = TerminalBufferLine(5)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(1, 'b', 1, TerminalCellAttributes())
      ..setCell(2, 'c', 1, TerminalCellAttributes());
    expect(line.getTrimmedLength(), 3);
  });

  test('xterm BufferLine 06', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes());
    expect(line.getTrimmedLength(), 2);
  });

  test('xterm BufferLine 07', () {
    final line = TerminalBufferLine(3)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..appendCombining(0, '\u0301');
    expect(line.getTrimmedLength(), 1);
    expect(line.translateToString(trimRight: true), 'a\u0301');
  });

  test('xterm BufferLine 08', () {
    final line = TerminalBufferLine(2)
      ..setCell(0, '𝄞', 1, TerminalCellAttributes());
    expect(line.getTrimmedLength(), 1);
  });

  test('xterm BufferLine 09', () {
    final line = TerminalBufferLine(1)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..addCodepointToCell(0, 0x301);
    expect(line.getCell(0)!.chars, 'a\u0301');
  });

  test('xterm BufferLine 10', () {
    final line = TerminalBufferLine(1)
      ..setCell(0, '', 0, TerminalCellAttributes())
      ..addCodepointToCell(0, 0x61);
    expect(line.getCell(0)!.chars, 'a');
    expect(line.getCell(0)!.width, 1);
  });

  test('xterm BufferLine 11', () {
    final line = _line('abcd')..insertCells(1, 2, TerminalCellAttributes());
    expect(line.translateToString(), 'a  b');
  });

  test('xterm BufferLine 12', () {
    final line = _line('abcd')..deleteCells(1, 2, TerminalCellAttributes());
    expect(line.translateToString(), 'ad  ');
  });

  test('xterm BufferLine 13', () {
    final line = _line('abcd')..replaceCells(1, 3, TerminalCellAttributes());
    expect(line.translateToString(), 'a  d');
  });

  test('xterm BufferLine 14', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes())
      ..setCell(2, 'x', 1, TerminalCellAttributes())
      ..insertCells(1, 1, TerminalCellAttributes());
    expect(line.getCell(0)!.width, 1);
    expect(line.getCell(3)!.width, 1);
  });

  test('xterm BufferLine 15', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes())
      ..setCell(2, 'x', 1, TerminalCellAttributes())
      ..deleteCells(1, 1, TerminalCellAttributes());
    expect(line.getCell(0)!.width, 1);
    expect(line.getCell(1)!.chars, 'x');
  });

  test('xterm BufferLine 16', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes())
      ..replaceCells(1, 2, TerminalCellAttributes());
    expect(line.getCell(0)!.width, 1);
    expect(line.getCell(1)!.width, 1);
  });

  test('xterm BufferLine 17', () {
    final line = TerminalBufferLine(1);
    expect(line.getCell(0)!.hasExtendedAttributes, isFalse);
    line.setCell(
      0,
      '',
      1,
      TerminalCellAttributes(underline: TerminalUnderlineStyle.curly),
    );
    expect(line.getCell(0)!.hasExtendedAttributes, isTrue);
  });

  test('xterm BufferLine 18', () {
    final attrs = TerminalCellAttributes(
      foreground: const TerminalCellColor.palette(123),
      underlineColor: const TerminalCellColor.palette(45),
    );
    final line = TerminalBufferLine(1)..setCell(0, 'a', 1, attrs);
    expect(line.getCell(0)!.underlineColorValue, 45);
    expect(line.getCell(0)!.isUnderlineColorPalette, isTrue);
  });

  test('xterm BufferLine 19', () {
    final attrs = TerminalCellAttributes(
      underlineColor: const TerminalCellColor.rgb(1, 2, 3),
    );
    final line = TerminalBufferLine(1)..setCell(0, 'a', 1, attrs);
    expect(line.getCell(0)!.underlineColorValue, 0x010203);
    expect(line.getCell(0)!.isUnderlineColorRgb, isTrue);
  });

  test('xterm BufferLine 20', () {
    final defaults = TerminalBufferLine(1).getCell(0)!;
    expect(defaults.isUnderlineColorDefault, isTrue);
    final palette = TerminalBufferLine(1)
      ..setCell(
        0,
        'a',
        1,
        TerminalCellAttributes(
          underlineColor: const TerminalCellColor.palette(2),
        ),
      );
    expect(palette.getCell(0)!.isUnderlineColorPalette, isTrue);
    final rgb = TerminalBufferLine(1)
      ..setCell(
        0,
        'a',
        1,
        TerminalCellAttributes(
          underlineColor: const TerminalCellColor.rgb(1, 2, 3),
        ),
      );
    expect(rgb.getCell(0)!.isUnderlineColorRgb, isTrue);
  });

  test('xterm BufferLine 21', () {
    final line = TerminalBufferLine(2)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(
        1,
        'b',
        1,
        TerminalCellAttributes(underline: TerminalUnderlineStyle.curly),
      );
    expect(line.getCell(0)!.underlineStyle, TerminalUnderlineStyle.none);
    expect(line.getCell(1)!.underlineStyle, TerminalUnderlineStyle.curly);
  });

  test('xterm BufferLine 22', () {
    for (var offset = 0; offset < 8; offset++) {
      final line = TerminalBufferLine(1)
        ..setCell(
          0,
          'a',
          1,
          TerminalCellAttributes(underlineVariantOffset: offset),
        );
      expect(line.getCell(0)!.underlineVariantOffset, offset);
    }
  });

  test('xterm BufferLine 23', () {
    final line = TerminalBufferLine(5)
      ..setCell(0, 'a', 1, TerminalCellAttributes(bold: true))
      ..setCell(1, 'e\u0301', 1, TerminalCellAttributes(bold: true))
      ..setCell(2, '𝄞', 1, TerminalCellAttributes(bold: true))
      ..setCell(3, '𓂀\u0301', 1, TerminalCellAttributes(bold: true))
      ..setCell(4, '１', 2, TerminalCellAttributes(bold: true));
    expect(line.getCell(0)!.code, 0x61);
    expect(line.getCell(1)!.code, 0x301);
    expect(line.getCell(2)!.code, 0x1d11e);
    expect(line.getCell(3)!.code, 0x301);
    expect(line.getCell(4)!.width, 2);
  });

  test('xterm BufferLine 24', () {
    final line = TerminalBufferLine(1)
      ..setCell(0, 'e', 1, TerminalCellAttributes(bold: true))
      ..addCodepointToCell(0, 0x301);
    expect(line.getCell(0)!.chars, 'e\u0301');
    expect(line.getCell(0)!.isBold, isTrue);
  });

  test('xterm BufferLine 25', () {
    final line = TerminalBufferLine(5)
      ..fill(TerminalCellAttributes(), chars: 'a')
      ..resize(10, TerminalCellAttributes(), chars: 'a');
    expect(line.translateToString(), 'a' * 10);
  });

  test('xterm BufferLine 26', () {
    final line = TerminalBufferLine(5)
      ..fill(TerminalCellAttributes(), chars: 'a')
      ..resize(10, TerminalCellAttributes(), chars: 'a');
    expect(line.length, 10);
    expect(line.getCell(9)!.chars, 'a');
  });

  test('xterm BufferLine 27', () {
    final line = TerminalBufferLine(10)
      ..fill(TerminalCellAttributes(), chars: 'a')
      ..resize(5, TerminalCellAttributes(), chars: 'a');
    expect(line.translateToString(), 'aaaaa');
  });

  test('xterm BufferLine 28', () {
    final line = TerminalBufferLine(10)
      ..fill(TerminalCellAttributes(), chars: 'a')
      ..resize(0, TerminalCellAttributes());
    expect(line.length, 0);
    expect(line.translateToString(), isEmpty);
  });

  test('xterm BufferLine 29', () {
    final line = TerminalBufferLine(10)
      ..fill(TerminalCellAttributes(), chars: 'a')
      ..setCell(2, '😁', 1, TerminalCellAttributes())
      ..setCell(9, '😁', 1, TerminalCellAttributes())
      ..resize(5, TerminalCellAttributes(), chars: 'a')
      ..resize(10, TerminalCellAttributes(), chars: 'a');
    expect(line.translateToString(), 'aa😁aaaaaaa');
  });

  test('xterm BufferLine 30', () {
    final line = TerminalBufferLine(2)
      ..fill(TerminalCellAttributes(), chars: 'e\u0301');
    final clone = line.copy();
    final copied = TerminalBufferLine(5)..copyFrom(line);
    expect(clone.translateToString(), 'e\u0301e\u0301');
    expect(copied.translateToString(), clone.translateToString());
  });

  test('xterm BufferLine 31', () {
    final columns = <int>[];
    final line = TerminalBufferLine(10);
    expect(line.translateToString(outputColumns: columns), ' ' * 10);
    expect(columns, List<int>.generate(11, (index) => index));
    expect(
      line.translateToString(trimRight: true, outputColumns: columns),
      isEmpty,
    );
    expect(columns, <int>[0]);
  });

  test('xterm BufferLine 32', () {
    final columns = <int>[];
    final line = TerminalBufferLine(10)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(2, 'a', 1, TerminalCellAttributes())
      ..setCell(4, 'a', 1, TerminalCellAttributes())
      ..setCell(5, 'a', 1, TerminalCellAttributes());
    expect(line.translateToString(outputColumns: columns), 'a a aa    ');
    expect(columns, List<int>.generate(11, (index) => index));
    expect(
      line.translateToString(trimRight: true, outputColumns: columns),
      'a a aa',
    );
    expect(columns, List<int>.generate(7, (index) => index));
  });

  test('xterm BufferLine 33', () {
    final columns = <int>[];
    final line = TerminalBufferLine(10)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(2, '𝄞', 1, TerminalCellAttributes())
      ..setCell(4, '𝄞', 1, TerminalCellAttributes())
      ..setCell(5, '𝄞', 1, TerminalCellAttributes());
    expect(line.translateToString(outputColumns: columns), 'a 𝄞 𝄞𝄞    ');
    expect(columns, <int>[0, 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 8, 9, 10]);
  });

  test('xterm BufferLine 34', () {
    final columns = <int>[];
    final line = TerminalBufferLine(10)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(2, 'e\u0301', 1, TerminalCellAttributes())
      ..setCell(4, 'e\u0301', 1, TerminalCellAttributes())
      ..setCell(5, 'e\u0301', 1, TerminalCellAttributes());
    expect(
      line.translateToString(trimRight: true, outputColumns: columns),
      'a e\u0301 e\u0301e\u0301',
    );
    expect(columns, <int>[0, 1, 2, 2, 3, 4, 4, 5, 5, 6]);
  });

  test('xterm BufferLine 35', () {
    final columns = <int>[];
    final line = TerminalBufferLine(10)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(2, '１', 2, TerminalCellAttributes())
      ..setCell(5, '１', 2, TerminalCellAttributes())
      ..setCell(7, '１', 2, TerminalCellAttributes());
    expect(line.translateToString(outputColumns: columns), 'a １ １１ ');
    expect(columns, <int>[0, 1, 2, 4, 5, 7, 9, 10]);
  });

  test('xterm BufferLine 36', () {
    final columns = <int>[];
    final line = TerminalBufferLine(10)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(2, 'a', 1, TerminalCellAttributes())
      ..setCell(4, 'a', 1, TerminalCellAttributes())
      ..setCell(5, 'a', 1, TerminalCellAttributes())
      ..setCell(6, ' ', 1, TerminalCellAttributes());
    expect(
      line.translateToString(trimRight: true, outputColumns: columns),
      'a a aa ',
    );
    expect(columns, List<int>.generate(8, (index) => index));
  });

  test('xterm BufferLine 37', () {
    final columns = <int>[];
    expect(
      TerminalBufferLine(10).translateToString(outputColumns: columns),
      ' ' * 10,
    );
    expect(columns, List<int>.generate(11, (index) => index));
  });

  test('xterm BufferLine 38', () {
    final columns = <int>[];
    final line = TerminalBufferLine(10)
      ..setCell(0, 'a', 1, TerminalCellAttributes());
    expect(
      line.translateToString(
        trimRight: true,
        endColumn: 0,
        outputColumns: columns,
      ),
      isEmpty,
    );
    expect(columns, <int>[0]);
  });

  test('xterm BufferLine 39', () {
    final line = _wideLine()
      ..insertCells(0, 3, TerminalCellAttributes(), chars: 'a')
      ..insertCells(4, 1, TerminalCellAttributes(), chars: 'a')
      ..insertCells(4, 1, TerminalCellAttributes(), chars: 'a');
    expect(line.translateToString(), 'aaa aa ￥ ');
  });

  test('xterm BufferLine 40', () {
    final line = _wideLine()
      ..replaceCells(0, 9, TerminalCellAttributes(), chars: 'a');
    expect(line.translateToString(), 'aaaaaaaaa ');
  });

  test('xterm BufferLine 41', () {
    final line = _extendedLine();
    expect(line.getCell(0)!.underlineStyle, TerminalUnderlineStyle.none);
    expect(line.getCell(1)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(line.getCell(2)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(line.getCell(3)!.underlineStyle, TerminalUnderlineStyle.dotted);
    expect(line.getCell(4)!.underlineStyle, TerminalUnderlineStyle.none);
  });

  test('xterm BufferLine 42', () {
    final line = _extendedLine();
    final destination = TerminalBufferLine(1).getCell(0)!;
    for (var index = 0; index < line.length; index++) {
      expect(
        line.getCell(index, destination)!.underlineStyle,
        line.getCell(index)!.underlineStyle,
      );
    }
  });

  test('xterm BufferLine 43', () {
    final attrs = TerminalCellAttributes(
      underline: TerminalUnderlineStyle.curly,
    );
    final line = TerminalBufferLine(3)..fill(attrs, chars: 'a');
    expect(
      List.generate(3, (index) => line.getCell(index)!.underlineStyle),
      List.filled(3, TerminalUnderlineStyle.curly),
    );
  });

  test('xterm BufferLine 44', () {
    final curly = TerminalCellAttributes(
      underline: TerminalUnderlineStyle.curly,
    );
    final dotted = TerminalCellAttributes(
      underline: TerminalUnderlineStyle.dotted,
    );
    final line = TerminalBufferLine(5)
      ..insertCells(1, 3, curly, chars: 'a')
      ..insertCells(2, 2, dotted, chars: 'a');
    expect(line.getCell(1)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(line.getCell(2)!.underlineStyle, TerminalUnderlineStyle.dotted);
    expect(line.getCell(3)!.underlineStyle, TerminalUnderlineStyle.dotted);
    expect(line.getCell(4)!.underlineStyle, TerminalUnderlineStyle.curly);
  });

  test('xterm BufferLine 45', () {
    final curly = TerminalCellAttributes(
      underline: TerminalUnderlineStyle.curly,
    );
    final double = TerminalCellAttributes(
      underline: TerminalUnderlineStyle.double,
    );
    final line = TerminalBufferLine(5)
      ..fill(curly, chars: 'a')
      ..deleteCells(1, 3, double, chars: 'a');
    expect(line.getCell(0)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(line.getCell(1)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(line.getCell(2)!.underlineStyle, TerminalUnderlineStyle.double);
    expect(line.getCell(4)!.underlineStyle, TerminalUnderlineStyle.double);
  });

  test('xterm BufferLine 46', () {
    final curly = TerminalCellAttributes(
      underline: TerminalUnderlineStyle.curly,
    );
    final double = TerminalCellAttributes(
      underline: TerminalUnderlineStyle.double,
    );
    final line = TerminalBufferLine(5)
      ..fill(curly, chars: 'a')
      ..replaceCells(1, 3, double, chars: 'a');
    expect(line.getCell(0)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(line.getCell(1)!.underlineStyle, TerminalUnderlineStyle.double);
    expect(line.getCell(2)!.underlineStyle, TerminalUnderlineStyle.double);
    expect(line.getCell(3)!.underlineStyle, TerminalUnderlineStyle.curly);
  });

  test('xterm BufferLine 47', () {
    final line = _extendedLine();
    final clone = line.copy();
    line.setCell(1, 'z', 1, TerminalCellAttributes());
    expect(clone.getCell(1)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(clone.getCell(3)!.underlineStyle, TerminalUnderlineStyle.dotted);
  });

  test('xterm BufferLine 48', () {
    final source = _extendedLine();
    final target = TerminalBufferLine(5)..copyFrom(source);
    source.setCell(1, 'z', 1, TerminalCellAttributes());
    expect(target.getCell(1)!.underlineStyle, TerminalUnderlineStyle.curly);
    expect(target.getCell(3)!.underlineStyle, TerminalUnderlineStyle.dotted);
  });

  test('xterm BufferLine 49', () {
    final cache = BufferLineStringCache();
    addTearDown(cache.dispose);
    final line = TerminalBufferLine(5, stringCache: cache)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..setCell(1, 'b', 1, TerminalCellAttributes())
      ..setCell(2, 'c', 1, TerminalCellAttributes());
    expect(line.translateToString(trimRight: true), 'abc');
    expect(cache.entries.single.value, 'abc');
    expect(cache.entries.single.isTrimmed, isTrue);
    expect(line.translateToString(), 'abc  ');
    expect(cache.entries.single.value, 'abc  ');
    expect(cache.entries.single.isTrimmed, isFalse);
    expect(line.translateToString(trimRight: true), 'abc');
    expect(cache.entries.single.value, 'abc  ');
    expect(line.translateToString(endColumn: 2), 'ab');
  });

  test('xterm BufferLine 50', () {
    final mutations = <void Function(TerminalBufferLine)>[
      (line) => line.setCell(0, 'b', 1, TerminalCellAttributes()),
      (line) => line.setCellFromCodepoint(0, 0x62, 1, TerminalCellAttributes()),
      (line) => line.addCodepointToCell(0, 0x301),
      (line) => line.insertCells(1, 1, TerminalCellAttributes()),
      (line) => line.deleteCells(1, 1, TerminalCellAttributes()),
      (line) => line.replaceCells(1, 3, TerminalCellAttributes()),
      (line) => line.resize(6, TerminalCellAttributes()),
      (line) => line.fill(TerminalCellAttributes(), chars: 'b'),
      (line) => line.copyFrom(TerminalBufferLine(5)),
      (line) => line.copyCellsFrom(TerminalBufferLine(5), 0, 0, 2),
    ];
    for (final mutate in mutations) {
      final cache = BufferLineStringCache();
      final line = TerminalBufferLine(5, stringCache: cache)
        ..fill(TerminalCellAttributes(), chars: 'a');
      expect(line.translateToString(), 'aaaaa');
      mutate(line);
      expect(cache.entries.single.value, isNull);
      expect(cache.entries.single.isTrimmed, isFalse);
      cache.dispose();
    }
  });
}

TerminalBufferLine _line(String value) {
  final line = TerminalBufferLine(value.length);
  for (var index = 0; index < value.length; index++) {
    line.setCell(index, value[index], 1, TerminalCellAttributes());
  }
  return line;
}

TerminalBufferLine _wideLine() {
  final line = TerminalBufferLine(10);
  for (var index = 0; index < line.length; index += 2) {
    line.setCell(index, '￥', 2, TerminalCellAttributes());
  }
  return line;
}

TerminalBufferLine _extendedLine() => TerminalBufferLine(5)
  ..setCell(0, 'a', 1, TerminalCellAttributes())
  ..setCell(
    1,
    'a',
    1,
    TerminalCellAttributes(underline: TerminalUnderlineStyle.curly),
  )
  ..setCell(
    2,
    'A',
    1,
    TerminalCellAttributes(underline: TerminalUnderlineStyle.curly),
  )
  ..setCell(
    3,
    'A',
    1,
    TerminalCellAttributes(underline: TerminalUnderlineStyle.dotted),
  )
  ..setCell(4, 'A', 1, TerminalCellAttributes());
