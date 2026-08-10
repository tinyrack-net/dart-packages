import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('MoveToCell', () {
    late TerminalBufferNamespace buffers;

    setUp(() {
      buffers = TerminalBufferNamespace(columns: 5, rows: 5, scrollback: 1000);
      buffers.active
        ..cursorX = 3
        ..cursorY = 3;
    });

    tearDown(() => buffers.dispose());

    group('normal buffer', () {
      test('should use the right directional escape sequences', () {
        expect(_move(buffers, 1, 3), '\u001b[D\u001b[D');
        expect(_move(buffers, 2, 3), '\u001b[D');
        expect(_move(buffers, 4, 3), '\u001b[C');
        expect(_move(buffers, 5, 3), '\u001b[C\u001b[C');
      });

      test(
        // Exact upstream test title is intentionally preserved for parity.
        // ignore: lines_longer_than_80_chars
        'should wrap around entire row instead of doing up and down when the Y value differs',
        () {
          for (final target in <(int, int, int, String)>[
            (1, 1, 12, 'D'),
            (3, 1, 10, 'D'),
            (5, 1, 8, 'D'),
            (1, 2, 7, 'D'),
            (3, 2, 5, 'D'),
            (5, 2, 3, 'D'),
            (1, 4, 3, 'C'),
            (3, 4, 5, 'C'),
            (5, 4, 7, 'C'),
            (1, 5, 8, 'C'),
            (3, 5, 10, 'C'),
            (5, 5, 12, 'C'),
          ]) {
            expect(
              _move(buffers, target.$1, target.$2),
              '\u001b[${target.$4}' * target.$3,
            );
          }
        },
      );

      test('should use the correct character for application cursor', () {
        expect(_move(buffers, 3, 1, application: true), '\u001bOD' * 10);
        expect(_move(buffers, 3, 2, application: true), '\u001bOD' * 5);
        expect(_move(buffers, 2, 3, application: true), '\u001bOD');
        expect(_move(buffers, 4, 3, application: true), '\u001bOC');
        expect(_move(buffers, 3, 4, application: true), '\u001bOC' * 5);
        expect(_move(buffers, 3, 5, application: true), '\u001bOC' * 10);
      });
    });

    group('alt buffer', () {
      test('should move the cursor across rows', () {
        buffers.useAlternate();
        buffers.active
          ..cursorX = 3
          ..cursorY = 3;
        expect(_move(buffers, 4, 4), '\u001b[B\u001b[C');
      });
    });
  });
}

String _move(
  TerminalBufferNamespace buffers,
  int x,
  int y, {
  bool application = false,
}) => moveToCellSequence(x, y, buffers, applicationCursor: application);
