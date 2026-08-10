import 'dart:math' as math;

import 'package:vtworld/src/core/buffer.dart';

enum _Direction {
  up('A'),
  down('B'),
  right('C'),
  left('D');

  const _Direction(this.code);
  final String code;
}

/// Builds the arrow-key sequence used by xterm's alt-click cursor movement.
String moveToCellSequence(
  int targetX,
  int targetY,
  TerminalBufferNamespace buffers, {
  required bool applicationCursor,
}) {
  final buffer = buffers.active;
  final startX = buffer.cursorX;
  final startY = buffer.cursorY;
  if (buffer.type == TerminalBufferType.alternate) {
    return _resetStartingRow(
          startX,
          startY,
          targetX,
          targetY,
          buffer,
          applicationCursor,
        ) +
        _moveToRequestedRow(startY, targetY, buffer, applicationCursor) +
        _moveToRequestedColumn(
          startX,
          startY,
          targetX,
          targetY,
          buffer,
          applicationCursor,
        );
  }
  if (startY == targetY) {
    final direction = startX > targetX ? _Direction.left : _Direction.right;
    return _sequence(direction, applicationCursor) * (startX - targetX).abs();
  }
  final direction = startY > targetY ? _Direction.left : _Direction.right;
  final rowDifference = (startY - targetY).abs();
  final cellsToMove =
      buffer.columns -
      (startY > targetY ? targetX : startX) +
      (rowDifference - 1) * buffer.columns +
      1 +
      (startY > targetY ? startX : targetX) -
      1;
  return _sequence(direction, applicationCursor) * cellsToMove;
}

String _resetStartingRow(
  int startX,
  int startY,
  int targetX,
  int targetY,
  TerminalBuffer buffer,
  bool applicationCursor,
) {
  if (_moveToRequestedRow(startY, targetY, buffer, applicationCursor).isEmpty) {
    return '';
  }
  final count = _bufferLine(
    startX,
    startY,
    startX,
    startY - _wrappedRowsForRow(startY, buffer),
    false,
    buffer,
  ).length;
  return _sequence(_Direction.left, applicationCursor) * count;
}

String _moveToRequestedRow(
  int startY,
  int targetY,
  TerminalBuffer buffer,
  bool applicationCursor,
) {
  final startRow = startY - _wrappedRowsForRow(startY, buffer);
  final endRow = targetY - _wrappedRowsForRow(targetY, buffer);
  final rows =
      (startRow - endRow).abs() - _wrappedRowsCount(startY, targetY, buffer);
  final direction = startY > targetY ? _Direction.up : _Direction.down;
  return _sequence(direction, applicationCursor) * rows;
}

String _moveToRequestedColumn(
  int startX,
  int startY,
  int targetX,
  int targetY,
  TerminalBuffer buffer,
  bool applicationCursor,
) {
  final rowSequence = _moveToRequestedRow(
    startY,
    targetY,
    buffer,
    applicationCursor,
  );
  final startRow = rowSequence.isNotEmpty
      ? targetY - _wrappedRowsForRow(targetY, buffer)
      : startY;
  final direction = _horizontalDirection(
    startX,
    startY,
    targetX,
    targetY,
    buffer,
    applicationCursor,
  );
  final count = _bufferLine(
    startX,
    startRow,
    targetX,
    targetY,
    direction == _Direction.right,
    buffer,
  ).length;
  return _sequence(direction, applicationCursor) * count;
}

int _wrappedRowsCount(int startY, int targetY, TerminalBuffer buffer) {
  var count = 0;
  final startRow = startY - _wrappedRowsForRow(startY, buffer);
  final endRow = targetY - _wrappedRowsForRow(targetY, buffer);
  final direction = startY > targetY ? -1 : 1;
  for (var index = 0; index < (startRow - endRow).abs(); index++) {
    if (buffer.getLine(startRow + direction * index)?.isWrapped ?? false) {
      count++;
    }
  }
  return count;
}

int _wrappedRowsForRow(int row, TerminalBuffer buffer) {
  var count = 0;
  var current = row;
  var wrapped = buffer.getLine(current)?.isWrapped ?? false;
  while (wrapped && current >= 0 && current < buffer.rows) {
    count++;
    wrapped = buffer.getLine(--current)?.isWrapped ?? false;
  }
  return count;
}

_Direction _horizontalDirection(
  int startX,
  int startY,
  int targetX,
  int targetY,
  TerminalBuffer buffer,
  bool applicationCursor,
) {
  final movesRows = _moveToRequestedRow(
    startY,
    targetY,
    buffer,
    applicationCursor,
  ).isNotEmpty;
  final startRow = movesRows
      ? targetY - _wrappedRowsForRow(targetY, buffer)
      : startY;
  if ((startX < targetX && startRow <= targetY) ||
      (startX >= targetX && startRow < targetY)) {
    return _Direction.right;
  }
  return _Direction.left;
}

String _bufferLine(
  int initialColumn,
  int initialRow,
  int endColumn,
  int endRow,
  bool forward,
  TerminalBuffer buffer,
) {
  var currentColumn = initialColumn;
  var currentRow = initialRow;
  var startColumn = initialColumn;
  final output = StringBuffer();
  while ((currentColumn != endColumn || currentRow != endRow) &&
      currentRow >= 0 &&
      currentRow < buffer.length) {
    currentColumn += forward ? 1 : -1;
    if (forward && currentColumn > buffer.columns - 1) {
      output.write(
        buffer.translateBufferLineToString(
          currentRow,
          startColumn: startColumn,
          endColumn: currentColumn,
        ),
      );
      currentColumn = 0;
      startColumn = 0;
      currentRow++;
    } else if (!forward && currentColumn < 0) {
      output.write(
        buffer.translateBufferLineToString(
          currentRow,
          endColumn: startColumn + 1,
        ),
      );
      currentColumn = buffer.columns - 1;
      startColumn = currentColumn;
      currentRow--;
    }
  }
  output.write(
    buffer.translateBufferLineToString(
      currentRow,
      startColumn: math.min(startColumn, currentColumn),
      endColumn: math.max(startColumn, currentColumn),
    ),
  );
  return output.toString();
}

String _sequence(_Direction direction, bool applicationCursor) =>
    '\u001b${applicationCursor ? 'O' : '['}${direction.code}';
