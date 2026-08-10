import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm BufferReflow 00', () {
    final lines = _wrappedCharacters('abcde');
    expect(
      reflowLargerGetLinesToRemove(
        lines,
        1,
        5,
        10,
        TerminalCellAttributes(),
        reflowCursorLine: false,
      ),
      isNotEmpty,
    );
  });

  test('xterm BufferReflow 01', () {
    final lines = _wrappedCharacters('abcde');
    expect(
      reflowLargerGetLinesToRemove(
        lines,
        1,
        5,
        2,
        TerminalCellAttributes(),
        reflowCursorLine: false,
      ),
      isEmpty,
    );
    expect(
      reflowLargerGetLinesToRemove(
        lines,
        1,
        5,
        2,
        TerminalCellAttributes(),
        reflowCursorLine: true,
      ),
      isNotEmpty,
    );
  });

  test('xterm BufferReflow 02', () {
    final line = TerminalBufferLine(12);
    for (var index = 0; index < 12; index += 4) {
      _setWide(line, index, '汉');
      _setWide(line, index + 2, '语');
    }
    expect(line.translateToString(), '汉语汉语汉语');
    expect(_lengths(line, 12, 11), <int>[10, 2]);
    expect(_lengths(line, 12, 10), <int>[10, 2]);
    expect(_lengths(line, 12, 9), <int>[8, 4]);
    expect(_lengths(line, 12, 8), <int>[8, 4]);
    expect(_lengths(line, 12, 7), <int>[6, 6]);
    expect(_lengths(line, 12, 6), <int>[6, 6]);
    expect(_lengths(line, 12, 5), <int>[4, 4, 4]);
    expect(_lengths(line, 12, 4), <int>[4, 4, 4]);
    expect(_lengths(line, 12, 3), <int>[2, 2, 2, 2, 2, 2]);
    expect(_lengths(line, 12, 2), <int>[2, 2, 2, 2, 2, 2]);
  });

  test('xterm BufferReflow 03', () {
    final line = TerminalBufferLine(4);
    _setWide(line, 0, '汉');
    _setWide(line, 2, '语');
    expect(line.translateToString(trimRight: true), '汉语');
    expect(_lengths(line, 4, 3), <int>[2, 2]);
    expect(_lengths(line, 4, 2), <int>[2, 2]);
  });

  test('xterm BufferReflow 04', () {
    final line = _mixedLine();
    expect(line.translateToString(), 'a汉语b');
    expect(_lengths(line, 6, 5), <int>[5, 1]);
    expect(_lengths(line, 6, 4), <int>[3, 3]);
    expect(_lengths(line, 6, 3), <int>[3, 3]);
    expect(_lengths(line, 6, 2), <int>[1, 2, 2, 1]);
  });

  test('xterm BufferReflow 05', () {
    final first = _mixedLine();
    final second = _mixedLine()..isWrapped = true;
    expect(first.translateToString(), 'a汉语b');
    expect(second.translateToString(), 'a汉语b');
    expect(_wrappedLengths(<TerminalBufferLine>[first, second], 6, 5), <int>[
      5,
      4,
      3,
    ]);
    expect(_wrappedLengths(<TerminalBufferLine>[first, second], 6, 4), <int>[
      3,
      4,
      4,
      1,
    ]);
    expect(_wrappedLengths(<TerminalBufferLine>[first, second], 6, 3), <int>[
      3,
      3,
      3,
      3,
    ]);
    expect(_wrappedLengths(<TerminalBufferLine>[first, second], 6, 2), <int>[
      1,
      2,
      2,
      2,
      2,
      2,
      1,
    ]);
  });

  test('xterm BufferReflow 06', () {
    final line = TerminalBufferLine(5);
    _setWide(line, 0, '汉');
    _setWide(line, 2, '语');
    expect(line.translateToString(trimRight: true), '汉语');
    expect(line.translateToString(), '汉语 ');
    expect(_lengths(line, 4, 3), <int>[2, 2]);
    expect(_lengths(line, 4, 2), <int>[2, 2]);
  });
}

List<TerminalBufferLine> _wrappedCharacters(String value) =>
    List<TerminalBufferLine>.generate(value.length, (index) {
      final line = TerminalBufferLine(1, isWrapped: index > 0)
        ..setCell(0, value[index], 1, TerminalCellAttributes());
      return line;
    });

TerminalBufferLine _mixedLine() {
  final line = TerminalBufferLine(6)
    ..setCell(0, 'a', 1, TerminalCellAttributes());
  _setWide(line, 1, '汉');
  _setWide(line, 3, '语');
  line.setCell(5, 'b', 1, TerminalCellAttributes());
  return line;
}

void _setWide(TerminalBufferLine line, int column, String value) {
  line.setCell(column, value, 2, TerminalCellAttributes());
}

List<int> _lengths(TerminalBufferLine line, int oldColumns, int newColumns) =>
    _wrappedLengths(<TerminalBufferLine>[line], oldColumns, newColumns);

List<int> _wrappedLengths(
  List<TerminalBufferLine> lines,
  int oldColumns,
  int newColumns,
) => reflowSmallerGetNewLineLengths(lines, oldColumns, newColumns);
