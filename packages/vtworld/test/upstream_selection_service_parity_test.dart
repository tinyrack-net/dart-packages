import 'package:characters/characters.dart';
import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm SelectionService 00', () {
    final h = _harness()..row(0, 'foo bar');
    for (final column in <int>[0, 1, 2]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, 'foo');
    }
    h.service.selectWordAt(3, 0);
    expect(h.service.selectionText, ' ');
    for (final column in <int>[4, 5, 6]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, 'bar');
    }
  });

  test('xterm SelectionService 01', () {
    final h = _harness()..row(0, 'a   b');
    for (final column in <int>[1, 2, 3]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, '   ');
    }
  });

  test('xterm SelectionService 02', () {
    final h = _harness();
    final line = h.terminal.buffer.active.getLine(0)!
      ..setCell(0, '中', 2, TerminalCellAttributes())
      ..setCell(2, '文', 2, TerminalCellAttributes())
      ..setCell(4, ' ', 1, TerminalCellAttributes())
      ..setCell(5, 'a', 1, TerminalCellAttributes())
      ..setCell(6, '中', 2, TerminalCellAttributes())
      ..setCell(8, '文', 2, TerminalCellAttributes())
      ..setCell(10, 'b', 1, TerminalCellAttributes());
    expect(line.getCell(1)!.width, 0);
    for (final column in <int>[0, 1, 2, 3]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, '中文');
    }
    for (final column in <int>[5, 6, 7, 8, 9, 10]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, 'a中文b');
    }
  });

  test('xterm SelectionService 03', () {
    final h = _harness()..row(0, '(cd)[ef]{gh}\'ij"');
    const expected = <int, String>{
      0: '(cd',
      1: 'cd',
      3: 'cd)',
      4: '[ef',
      7: 'ef]',
      8: '{gh',
      11: 'gh}',
      12: "'ij",
      15: 'ij"',
    };
    for (final entry in expected.entries) {
      h.service.selectWordAt(entry.key, 0);
      expect(h.service.selectionText, entry.value);
    }
  });

  test('xterm SelectionService 04', () {
    final h = _harness()
      ..row(0, '                 foo')
      ..row(1, 'bar                 ', wrapped: true);
    h.service.selectWordAt(1, 1);
    expect(h.service.selectionText, 'foobar');
    h.service.selectWordAt(18, 0);
    expect(h.service.selectionText, 'foobar');
  });

  test('xterm SelectionService 05', () {
    final h = _harness()
      ..row(0, '                 foo')
      ..row(1, 'a' * 20, wrapped: true)
      ..row(2, 'b' * 20, wrapped: true)
      ..row(3, 'c' * 20, wrapped: true)
      ..row(4, 'bar                 ', wrapped: true);
    const suffix = 'bar';
    final expected = 'foo${'a' * 20}${'b' * 20}${'c' * 20}$suffix';
    for (final position in <TerminalBufferPosition>[
      const TerminalBufferPosition(18, 0),
      const TerminalBufferPosition(10, 1),
      const TerminalBufferPosition(10, 2),
      const TerminalBufferPosition(10, 3),
      const TerminalBufferPosition(1, 4),
    ]) {
      h.service.selectWordAt(position.x, position.y);
      expect(h.service.selectionText, expected);
    }
  });

  test('xterm SelectionService 06', () {
    final h = _harness()..row(0, ' ⚽ a');
    h.service.selectWordAt(1, 0);
    expect(h.service.selectionText, '⚽');
  });

  test('xterm SelectionService 07', () {
    final h = _harness()..row(0, ' ⚽⚽ a');
    for (final column in <int>[1, 2]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, '⚽⚽');
    }
  });

  test('xterm SelectionService 08', () {
    final h = _harness()
      ..cells(0, <String>[' ', '👨‍', '👩‍', '👧‍', '👦', ' ', 'a']);
    for (final column in <int>[1, 2, 3, 4]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, '👨‍👩‍👧‍👦');
    }
  });

  test('xterm SelectionService 09', () {
    final h = _harness()..cells(0, ' ⚽ab cd⚽ ef⚽gh'.characters.toList());
    for (final column in <int>[1, 2, 3]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, '⚽ab');
    }
    for (final column in <int>[9, 10, 11, 12, 13]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, 'ef⚽gh');
    }
  });

  test('xterm SelectionService 10', () {
    const flag = '🏴󠁧󠁢󠁥󠁮󠁧󠁿';
    final h = _harness()
      ..cells(0, <String>[' ', flag, 'a', 'b', ' ', 'c', 'd', flag]);
    for (final column in <int>[1, 2, 3]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, '${flag}ab');
    }
    for (final column in <int>[5, 6, 7]) {
      h.service.selectWordAt(column, 0);
      expect(h.service.selectionText, 'cd$flag');
    }
  });

  test('xterm SelectionService 11', () {
    final h = _harness()..row(0, 'foo bar');
    expect(h.service.selectLineAt(0), isTrue);
    expect(h.service.selectionText, 'foo bar');
    expect(
      h.terminal.getSelectionPosition(),
      const TerminalBufferRange(
        start: TerminalBufferPosition(0, 0),
        end: TerminalBufferPosition(20, 0),
      ),
    );
  });

  test('xterm SelectionService 12', () {
    final h = _harness()
      ..row(0, 'foo')
      ..row(1, 'bar', wrapped: true);
    h.service.selectLineAt(0);
    expect(h.service.selectionText, 'foobar');
    expect(
      h.terminal.getSelectionPosition()!.end,
      const TerminalBufferPosition(20, 1),
    );
  });

  test('xterm SelectionService 13', () {
    final h = _harness(rows: 5)
      ..row(0, '1')
      ..row(1, '2')
      ..row(2, '3')
      ..row(3, '4')
      ..row(4, '5');
    h.service.selectAll();
    expect(h.service.selectionText, '1\n2\n3\n4\n5');
  });

  test('xterm SelectionService 14', () {
    final h = _harness(rows: 3);
    h.service.selectLines(1, 1);
    expect(
      h.terminal.getSelectionPosition()!.start,
      const TerminalBufferPosition(0, 1),
    );
    expect(
      h.terminal.getSelectionPosition()!.end,
      const TerminalBufferPosition(20, 1),
    );
  });

  test('xterm SelectionService 15', () {
    final h = _harness(rows: 5);
    h.service.selectLines(1, 3);
    expect(
      h.terminal.getSelectionPosition()!.start,
      const TerminalBufferPosition(0, 1),
    );
    expect(
      h.terminal.getSelectionPosition()!.end,
      const TerminalBufferPosition(20, 3),
    );
  });

  test('xterm SelectionService 16', () {
    final h = _harness(rows: 2);
    h.service.selectLines(-1, 0);
    expect(
      h.terminal.getSelectionPosition()!.start,
      const TerminalBufferPosition(0, 0),
    );
  });

  test('xterm SelectionService 17', () {
    final h = _harness(rows: 2);
    h.service.selectLines(1, 2);
    expect(
      h.terminal.getSelectionPosition()!.end,
      const TerminalBufferPosition(20, 1),
    );
  });

  test('xterm SelectionService 18', () {
    final h = _harness();
    expect(h.service.hasSelection, isFalse);
    h.terminal.select(0, 0, 0);
    expect(h.service.hasSelection, isFalse);
    h.terminal.select(0, 0, 1);
    expect(h.service.hasSelection, isTrue);
  });

  test('xterm SelectionService 19', () {
    final h = _harness(rows: 3)
      ..row(0, 'abcdefghij')
      ..row(1, 'klmnopqrst')
      ..row(2, 'uvwxyz');
    h.service.selectColumns(2, 0, 4, 2);
    expect(h.service.selectionText, 'cd\nmn\nwx');
  });

  test('xterm SelectionService 20', () {
    final h = _harness(rows: 3);
    h.terminal.buffer.active
        .getLine(0)!
        .setCell(0, 'a', 1, TerminalCellAttributes());
    h.terminal.buffer.active
        .getLine(1)!
        .setCell(0, '語', 2, TerminalCellAttributes());
    h.terminal.buffer.active
        .getLine(2)!
        .setCell(0, 'b', 1, TerminalCellAttributes());
    h.service.selectColumns(0, 0, 1, 2);
    expect(h.service.selectionText, 'a\n語\nb');
  });

  test('xterm SelectionService 21', () {
    final h = _harness(rows: 3)
      ..row(0, 'a')
      ..row(1, '☃')
      ..row(2, 'c');
    h.service.selectColumns(0, 0, 1, 2);
    expect(h.service.selectionText, 'a\n☃\nc');
  });

  test('xterm SelectionService 22', () {
    final h = _harness(rows: 3)
      ..cells(0, <String>['a', ' '])
      ..cells(1, <String>['😁', ' '])
      ..cells(2, <String>['c', ' ']);
    h.service.selectColumns(0, 0, 1, 2);
    expect(h.service.selectionText, 'a\n😁\nc');
  });

  test('xterm SelectionService 23', () {
    const start = TerminalBufferPosition(2, 0);
    const end = TerminalBufferPosition(2, 1);
    for (final point in <TerminalBufferPosition>[
      const TerminalBufferPosition(2, 0),
      const TerminalBufferPosition(10, 0),
      const TerminalBufferPosition(0, 1),
      const TerminalBufferPosition(1, 1),
    ]) {
      expect(
        TerminalSelectionService.areCoordinatesInSelection(point, start, end),
        isTrue,
      );
    }
    expect(
      TerminalSelectionService.areCoordinatesInSelection(
        const TerminalBufferPosition(1, 0),
        start,
        end,
      ),
      isFalse,
    );
  });

  test('xterm SelectionService 24', () {
    expect(
      TerminalSelectionService.shouldForceSelection(
        altKey: false,
        shiftKey: false,
        mouseEventsRequireAlt: true,
        mouseEventsActive: true,
        isMac: false,
        macOptionClickForcesSelection: false,
      ),
      isTrue,
    );
    expect(
      TerminalSelectionService.shouldForceSelection(
        altKey: true,
        shiftKey: true,
        mouseEventsRequireAlt: true,
        mouseEventsActive: true,
        isMac: false,
        macOptionClickForcesSelection: false,
      ),
      isFalse,
    );
  });

  test('xterm SelectionService 25', () {
    expect(
      TerminalSelectionService.shouldForceSelection(
        altKey: true,
        shiftKey: true,
        mouseEventsRequireAlt: true,
        mouseEventsActive: true,
        isMac: true,
        macOptionClickForcesSelection: true,
      ),
      isFalse,
    );
  });
}

_SelectionHarness _harness({int rows = 20}) {
  final terminal = Terminal(options: TerminalOptions(cols: 20, rows: rows));
  addTearDown(terminal.dispose);
  return _SelectionHarness(terminal);
}

final class _SelectionHarness {
  _SelectionHarness(this.terminal)
    : service = TerminalSelectionService(terminal);

  final Terminal terminal;
  final TerminalSelectionService service;

  void row(int row, String value, {bool wrapped = false}) {
    cells(row, value.characters.toList(), wrapped: wrapped);
  }

  void cells(int row, List<String> values, {bool wrapped = false}) {
    final line = terminal.buffer.active.getLine(row)!..isWrapped = wrapped;
    for (var index = 0; index < values.length; index++) {
      line.setCell(index, values[index], 1, TerminalCellAttributes());
    }
  }
}
