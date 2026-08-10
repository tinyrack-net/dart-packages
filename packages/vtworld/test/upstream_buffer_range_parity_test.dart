import 'package:test/test.dart';
import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/buffer_range.dart';

void main() {
  group('BufferRange', () {
    group('getRangeLength', () {
      test('should get range for single line', () {
        expect(getRangeLength(_range(1, 1, 4, 1), 0), 4);
      });

      test('should throw for invalid range', () {
        expect(
          () => getRangeLength(_range(1, 3, 1, 1), 0),
          throwsArgumentError,
        );
      });

      test('should get range multiple lines', () {
        expect(getRangeLength(_range(1, 1, 4, 5), 5), 24);
      });

      test('should get range for end line right after start line', () {
        expect(getRangeLength(_range(1, 1, 7, 2), 5), 12);
      });
    });
  });
}

TerminalBufferRange _range(int x1, int y1, int x2, int y2) =>
    TerminalBufferRange(
      start: TerminalBufferPosition(x1, y1),
      end: TerminalBufferPosition(x2, y2),
    );
