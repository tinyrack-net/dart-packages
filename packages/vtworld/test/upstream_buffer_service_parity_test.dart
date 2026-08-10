import 'package:test/test.dart';
import 'package:vtworld/src/core/buffer_service.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('BufferService', () {
    final eraseAttributes = TerminalCellAttributes();

    group('scroll', () {
      test(
        // Exact upstream test title is intentionally preserved for parity.
        // ignore: lines_longer_than_80_chars
        'should decrement ydisp when the buffer is full and the user has scrolled up',
        () {
          final service = _service(rows: 3, columns: 10, scrollback: 2);
          addTearDown(service.dispose);
          while (service.buffer.length < 5) {
            service.scroll(eraseAttributes);
          }
          service
            ..isUserScrolling = true
            ..displayY = 2;
          final baseBefore = service.buffer.baseY;
          service.scroll(eraseAttributes);
          expect(service.buffer.baseY, baseBefore);
          expect(service.displayY, 1);
        },
      );

      test(
        // Exact upstream test title is intentionally preserved for parity.
        // ignore: lines_longer_than_80_chars
        'should not advance ydisp with ybase while the user has scrolled up and the buffer is not full',
        () {
          final service = _service(rows: 3, columns: 10, scrollback: 2);
          addTearDown(service.dispose);
          service
            ..isUserScrolling = true
            ..displayY = 0;
          final baseBefore = service.buffer.baseY;
          service.scroll(eraseAttributes);
          expect(service.buffer.baseY, baseBefore + 1);
          expect(service.displayY, 0);
        },
      );

      test('should follow ybase with ydisp when the user is not scrolling', () {
        final service = _service(rows: 3, columns: 10, scrollback: 2);
        addTearDown(service.dispose);
        while (service.buffer.length < 5) {
          service.scroll(eraseAttributes);
        }
        service
          ..isUserScrolling = false
          ..scroll(eraseAttributes);
        expect(service.displayY, service.buffer.baseY);
      });

      test(
        // Exact upstream test title is intentionally preserved for parity.
        // ignore: lines_longer_than_80_chars
        'should scroll within DECSTBM margins without affecting lines outside the region',
        () {
          final service = _service(rows: 5, columns: 10, scrollback: 10);
          addTearDown(service.dispose);
          for (final (row, character) in <(int, String)>[
            (0, 'A'),
            (1, 'B'),
            (2, 'C'),
            (3, 'D'),
            (4, 'E'),
          ]) {
            service.buffer
                .getLine(row)!
                .setCell(0, character, 1, eraseAttributes);
          }
          service
            ..scrollTop = 1
            ..scrollBottom = 3
            ..scroll(eraseAttributes);
          expect(_line(service, 0), 'A');
          expect(_line(service, 1), 'C');
          expect(_line(service, 2), 'D');
          expect(_line(service, 3), '');
          expect(_line(service, 4), 'E');
        },
      );
    });

    group('scrollLines', () {
      test('should move ydisp and set isUserScrolling when scrolling up', () {
        final service = _service(rows: 10, columns: 80, scrollback: 10);
        addTearDown(service.dispose);
        _addHistory(service, eraseAttributes, 5);
        final events = <int>[];
        service.onScroll.listen(events.add);
        service.scrollLines(-2);
        expect(service.displayY, 3);
        expect(service.isUserScrolling, isTrue);
        expect(events, <int>[3]);
      });

      test('should not scroll above the top of the buffer', () {
        final service = _service(rows: 10, columns: 80, scrollback: 10);
        addTearDown(service.dispose);
        _addHistory(service, eraseAttributes, 5);
        service
          ..displayY = 0
          ..scrollLines(-1);
        expect(service.displayY, 0);
        expect(service.isUserScrolling, isFalse);
      });

      test('should clear isUserScrolling when scrolling to the bottom', () {
        final service = _service(rows: 10, columns: 80, scrollback: 10);
        addTearDown(service.dispose);
        _addHistory(service, eraseAttributes, 5);
        service
          ..displayY = 2
          ..isUserScrolling = true
          ..scrollLines(10);
        expect(service.displayY, 5);
        expect(service.isUserScrolling, isFalse);
      });
    });
  });
}

TerminalBufferService _service({
  required int rows,
  required int columns,
  required int scrollback,
}) => TerminalBufferService(
  TerminalOptions(cols: columns, rows: rows, scrollback: scrollback),
);

void _addHistory(
  TerminalBufferService service,
  TerminalCellAttributes attributes,
  int lines,
) {
  for (var index = 0; index < lines; index++) {
    service.scroll(attributes);
  }
}

String _line(TerminalBufferService service, int row) => service.buffer
    .getLine(service.buffer.baseY + row)!
    .translateToString(trimRight: true);
