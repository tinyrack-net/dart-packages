import 'package:test/test.dart';
import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/windows_mode.dart';

void main() {
  group('WindowsMode', () {
    group('updateWindowsModeWrappedState', () {
      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should mark the next line wrapped when the previous line ends in a non-whitespace character',
        () {
          final buffer = _bufferWithCursorOnSecondLine();
          final previous = buffer.getLine(buffer.baseY)!;
          for (var index = 0; index < buffer.columns; index++) {
            previous.setCell(index, 'a', 1, TerminalCellAttributes());
          }

          updateWindowsModeWrappedState(buffer, buffer.columns);

          expect(buffer.getLine(buffer.baseY + 1)!.isWrapped, isTrue);
        },
      );

      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should not mark the next line wrapped when the previous line ends in whitespace',
        () {
          final buffer = _bufferWithCursorOnSecondLine();
          final previous = buffer.getLine(buffer.baseY)!;
          for (var index = 0; index < buffer.columns - 1; index++) {
            previous.setCell(index, 'a', 1, TerminalCellAttributes());
          }
          previous.setCell(
            buffer.columns - 1,
            ' ',
            1,
            TerminalCellAttributes(),
          );

          updateWindowsModeWrappedState(buffer, buffer.columns);

          expect(buffer.getLine(buffer.baseY + 1)!.isWrapped, isFalse);
        },
      );

      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should not mark the next line wrapped when the previous line ends in a null cell',
        () {
          final buffer = _bufferWithCursorOnSecondLine();

          updateWindowsModeWrappedState(buffer, buffer.columns);

          expect(buffer.getLine(buffer.baseY + 1)!.isWrapped, isFalse);
        },
      );
    });
  });
}

TerminalBuffer _bufferWithCursorOnSecondLine() {
  final namespace = TerminalBufferNamespace(
    columns: 10,
    rows: 5,
    scrollback: 1000,
  );
  return namespace.active..cursorY = 1;
}
