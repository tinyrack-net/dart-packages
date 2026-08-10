import 'package:vtworld/src/core/buffer.dart';

/// Coordinate-only selection state used by xterm's selection service.
final class SelectionModel {
  /// Creates a model over live terminal dimensions.
  SelectionModel({
    required this.columns,
    required this.rows,
    required this.bufferBaseY,
  });

  /// Supplies the current terminal column count.
  final int Function() columns;

  /// Supplies the current terminal row count.
  final int Function() rows;

  /// Supplies the current active buffer base row.
  final int Function() bufferBaseY;

  /// Whether select-all overrides the explicit endpoints.
  bool isSelectAllActive = false;

  /// Minimum selection length established by word or line selection.
  int selectionStartLength = 0;

  /// Raw selection anchor.
  TerminalBufferPosition? selectionStart;

  /// Raw moving selection endpoint.
  TerminalBufferPosition? selectionEnd;

  /// Clears all explicit and derived selection state.
  void clearSelection() {
    selectionStart = null;
    selectionEnd = null;
    isSelectAllActive = false;
    selectionStartLength = 0;
  }

  /// Final ordered selection start.
  TerminalBufferPosition? get finalSelectionStart {
    if (isSelectAllActive) return const TerminalBufferPosition(0, 0);
    final start = selectionStart;
    final end = selectionEnd;
    if (end == null || start == null) return start;
    return areSelectionValuesReversed() ? end : start;
  }

  /// Final ordered exclusive selection end.
  TerminalBufferPosition? get finalSelectionEnd {
    final columnCount = columns();
    if (isSelectAllActive) {
      return TerminalBufferPosition(columnCount, bufferBaseY() + rows() - 1);
    }
    final start = selectionStart;
    if (start == null) return null;
    final end = selectionEnd;
    if (end == null || areSelectionValuesReversed()) {
      return _endFromStartLength(start, columnCount, preserveTrailingEol: true);
    }
    if (selectionStartLength != 0 && end.y == start.y) {
      final startPlusLength = start.x + selectionStartLength;
      if (startPlusLength > columnCount) {
        return TerminalBufferPosition(
          startPlusLength % columnCount,
          start.y + startPlusLength ~/ columnCount,
        );
      }
      return TerminalBufferPosition(
        startPlusLength > end.x ? startPlusLength : end.x,
        end.y,
      );
    }
    return end;
  }

  TerminalBufferPosition _endFromStartLength(
    TerminalBufferPosition start,
    int columns, {
    required bool preserveTrailingEol,
  }) {
    final startPlusLength = start.x + selectionStartLength;
    if (startPlusLength > columns) {
      if (preserveTrailingEol && startPlusLength % columns == 0) {
        return TerminalBufferPosition(
          columns,
          start.y + startPlusLength ~/ columns - 1,
        );
      }
      return TerminalBufferPosition(
        startPlusLength % columns,
        start.y + startPlusLength ~/ columns,
      );
    }
    return TerminalBufferPosition(startPlusLength, start.y);
  }

  /// Whether the raw end precedes the raw start.
  bool areSelectionValuesReversed() {
    final start = selectionStart;
    final end = selectionEnd;
    if (start == null || end == null) return false;
    return start.y > end.y || start.y == end.y && start.x > end.x;
  }

  /// Adjusts the selection after [amount] buffer rows are trimmed.
  bool handleTrim(int amount) {
    final start = selectionStart;
    if (start != null) {
      selectionStart = TerminalBufferPosition(start.x, start.y - amount);
    }
    final end = selectionEnd;
    if (end != null) {
      selectionEnd = TerminalBufferPosition(end.x, end.y - amount);
    }
    if (selectionEnd case final trimmedEnd? when trimmedEnd.y < 0) {
      clearSelection();
      return true;
    }
    if (selectionStart case final trimmedStart? when trimmedStart.y < 0) {
      selectionStart = const TerminalBufferPosition(0, 0);
      return true;
    }
    return false;
  }
}
