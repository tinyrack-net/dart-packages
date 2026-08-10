import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('CharacterJoinerService', () {
    late TerminalBufferNamespace buffers;
    late CharacterJoinerService service;

    setUp(() {
      buffers = TerminalBufferNamespace(columns: 16, rows: 10, scrollback: 0);
      _write(buffers.active.getLine(0)!, 0, 'a -> b -> c -> d');
      _write(buffers.active.getLine(1)!, 0, 'a -> b => c -> d');
      _write(buffers.active.getLine(2)!, 0, 'a -> b -', style: 1);
      _write(buffers.active.getLine(2)!, 8, '> c -> d');
      _write(buffers.active.getLine(3)!, 0, 'no joined ranges');
      _write(buffers.active.getLine(5)!, 0, 'a', style: 1);
      _write(buffers.active.getLine(5)!, 1, ' -> b -> c -> ');
      _write(buffers.active.getLine(5)!, 15, 'd', style: 2);
      final line6 = buffers.active.getLine(6)!;
      _write(line6, 0, 'wi');
      line6
        ..setCell(2, '￥', 2, TerminalCellAttributes())
        ..setCell(3, '', 0, TerminalCellAttributes());
      _write(line6, 4, 'deemo');
      line6.setCell(9, '\u00f0\u009f\u0098\u0081', 1, TerminalCellAttributes());
      _write(line6, 10, ' jiabc');
      service = CharacterJoinerService(buffers);
    });

    tearDown(() => buffers.dispose());

    test('has no joiners upon creation', () {
      expect(service.getJoinedCharacters(0), isEmpty);
    });

    test('joined cell data and failing handlers remain renderer-safe', () {
      final cell = buffers.active.getLine(0)!.getCell(0)!;
      final joined = JoinedCellData(cell, 'ab', 2);
      expect(joined.firstCell, same(cell));
      expect(joined.chars, 'ab');
      expect(joined.width, 2);
      expect(joined.code, 0x1fffff);
      expect(joined.isCombined, isTrue);
      service
        ..register((_) => throw StateError('first'))
        ..register((_) => throw StateError('second'));
      expect(service.getJoinedCharacters(0), isEmpty);
      expect(service.getJoinedCharacters(-1), isEmpty);
    });

    test('returns ranges matched by the registered joiners', () {
      service.register(_substringJoiner('->'));
      _expectRanges(service.getJoinedCharacters(0), <(int, int)>[
        (2, 4),
        (7, 9),
        (12, 14),
      ]);
    });

    test('processes the input using all provided joiners', () {
      service
        ..register(_substringJoiner('->'))
        ..register(_substringJoiner('=>'));
      _expectRanges(service.getJoinedCharacters(1), <(int, int)>[
        (2, 4),
        (7, 9),
        (12, 14),
      ]);
    });

    test('removes deregistered joiners from future calls', () {
      final first = service.register(_substringJoiner('->'));
      final second = service.register(_substringJoiner('=>'));
      expect(service.deregister(first), isTrue);
      _expectRanges(service.getJoinedCharacters(1), <(int, int)>[(7, 9)]);
      expect(service.deregister(second), isTrue);
      expect(service.getJoinedCharacters(1), isEmpty);
    });

    test("doesn't process joins on differently-styled characters", () {
      service.register(_substringJoiner('->'));
      _expectRanges(service.getJoinedCharacters(2), <(int, int)>[
        (2, 4),
        (12, 14),
      ]);
    });

    test(
      'returns an empty list of ranges if there is nothing to be joined',
      () {
        service.register(_substringJoiner('->'));
        expect(service.getJoinedCharacters(3), isEmpty);
      },
    );

    test('returns an empty list of ranges if the line is empty', () {
      service.register(_substringJoiner('->'));
      expect(service.getJoinedCharacters(4), isEmpty);
    });

    test(
      'returns false when trying to deregister a joiner that does not exist',
      () {
        service.register(_substringJoiner('->'));
        expect(service.deregister(123), isFalse);
      },
    );

    test("doesn't process same-styled ranges that only have one character", () {
      service
        ..register(_substringJoiner('a'))
        ..register(_substringJoiner('b'))
        ..register(_substringJoiner('d'));
      _expectRanges(service.getJoinedCharacters(5), <(int, int)>[(5, 6)]);
    });

    test('handles ranges that extend all the way to the end of the line', () {
      service.register(_substringJoiner('-> d'));
      _expectRanges(service.getJoinedCharacters(2), <(int, int)>[(12, 16)]);
    });

    test('handles adjacent ranges', () {
      service
        ..register(_substringJoiner('->'))
        ..register(_substringJoiner('> c '));
      _expectRanges(service.getJoinedCharacters(2), <(int, int)>[
        (2, 4),
        (8, 12),
        (12, 14),
      ]);
    });

    test('handles fullwidth characters in the middle of ranges', () {
      service.register(_substringJoiner('wi￥de'));
      _expectRanges(service.getJoinedCharacters(6), <(int, int)>[(0, 6)]);
    });

    test('handles fullwidth characters at the end of ranges', () {
      service.register(_substringJoiner('wi￥'));
      _expectRanges(service.getJoinedCharacters(6), <(int, int)>[(0, 4)]);
    });

    test('handles emojis in the middle of ranges', () {
      service.register(_substringJoiner('emo\u00f0\u009f\u0098\u0081 ji'));
      _expectRanges(service.getJoinedCharacters(6), <(int, int)>[(6, 13)]);
    });

    test('handles emojis at the end of ranges', () {
      service.register(_substringJoiner('emo\u00f0\u009f\u0098\u0081 '));
      _expectRanges(service.getJoinedCharacters(6), <(int, int)>[(6, 11)]);
    });

    test('handles ranges after wide and emoji characters', () {
      service.register(_substringJoiner('abc'));
      _expectRanges(service.getJoinedCharacters(6), <(int, int)>[(13, 16)]);
    });

    group('range merging', () {
      void merged(
        List<(int, int)> first,
        (int, int) second,
        List<(int, int)> expected,
      ) {
        service
          ..register((_) => _ranges(first))
          ..register((_) => _ranges(<(int, int)>[second]));
        _expectRanges(service.getJoinedCharacters(0), expected);
      }

      test('inserts a new range before the existing ones', () {
        merged(<(int, int)>[(1, 2), (2, 3)], (0, 1), <(int, int)>[
          (0, 1),
          (1, 2),
          (2, 3),
        ]);
      });

      test('inserts in between two ranges', () {
        merged(<(int, int)>[(0, 2), (4, 6)], (2, 4), <(int, int)>[
          (0, 2),
          (2, 4),
          (4, 6),
        ]);
      });

      test('inserts after the last range', () {
        merged(<(int, int)>[(0, 2), (4, 6)], (6, 8), <(int, int)>[
          (0, 2),
          (4, 6),
          (6, 8),
        ]);
      });

      test('extends the beginning of a range', () {
        merged(<(int, int)>[(0, 2), (4, 6)], (3, 5), <(int, int)>[
          (0, 2),
          (3, 6),
        ]);
      });

      test('extends the end of a range', () {
        merged(<(int, int)>[(0, 2), (4, 6)], (1, 4), <(int, int)>[
          (0, 4),
          (4, 6),
        ]);
      });

      test('extends the last range', () {
        merged(<(int, int)>[(0, 2), (4, 6)], (5, 7), <(int, int)>[
          (0, 2),
          (4, 7),
        ]);
      });

      test('connects two ranges', () {
        merged(<(int, int)>[(0, 2), (4, 6)], (1, 5), <(int, int)>[(0, 6)]);
      });

      test('connects more than two ranges', () {
        merged(
          <(int, int)>[(0, 2), (4, 6), (8, 10), (12, 14)],
          (1, 10),
          <(int, int)>[(0, 10), (12, 14)],
        );
      });
    });
  });
}

void _write(TerminalBufferLine line, int offset, String text, {int style = 0}) {
  final attributes = TerminalCellAttributes(
    foreground: TerminalCellColor.rgb(style, style, style),
  );
  for (var index = 0; index < text.length; index++) {
    line.setCell(offset + index, text[index], 1, attributes);
  }
}

TerminalCharacterJoiner _substringJoiner(String substring) => (text) {
  final ranges = <TerminalCharacterJoin>[];
  var searchIndex = 0;
  while (true) {
    final index = text.indexOf(substring, searchIndex);
    if (index == -1) return ranges;
    final end = index + substring.length;
    ranges.add(TerminalCharacterJoin(index, end));
    searchIndex = end;
  }
};

List<TerminalCharacterJoin> _ranges(List<(int, int)> values) =>
    <TerminalCharacterJoin>[
      for (final value in values) TerminalCharacterJoin(value.$1, value.$2),
    ];

void _expectRanges(
  List<TerminalCharacterJoin> actual,
  List<(int, int)> expected,
) {
  expect(<(int, int)>[
    for (final range in actual) (range.start, range.end),
  ], expected);
}
