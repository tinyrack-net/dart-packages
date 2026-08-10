import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/terminal.dart';

/// Headless portion of xterm's selection service.
///
/// Pointer coordinate conversion remains in `TerminalView`; word, line,
/// column, selection containment and mouse-protocol precedence live here so
/// every renderer observes the same buffer behavior.
final class TerminalSelectionService {
  /// Creates a selection service for [terminal].
  const TerminalSelectionService(this.terminal);

  /// Terminal whose active buffer and selection model are used.
  final Terminal terminal;

  /// Selected text, matching xterm's selection service getter.
  String get selectionText => terminal.getSelection();

  /// Whether a non-empty selection exists.
  bool get hasSelection => terminal.hasSelection();

  /// Selects the word or whitespace run at the buffer coordinate.
  bool selectWordAt(int column, int row, {bool allowWhitespaceOnly = true}) {
    final range = wordRange(
      TerminalBufferPosition(column, row),
      allowWhitespaceOnly: allowWhitespaceOnly,
    );
    if (range == null) return false;
    _selectRange(range);
    return true;
  }

  /// Selects the complete logical line containing [row].
  bool selectLineAt(int row) {
    final range = wrappedLineRange(row);
    if (range == null) return false;
    _selectRange(range);
    return true;
  }

  /// Selects the complete active buffer.
  void selectAll() => terminal.selectAll();

  /// Selects inclusive buffer rows, clamped to the available line range.
  void selectLines(int start, int end) => terminal.selectLines(start, end);

  /// Selects a rectangular range.
  void selectColumns(int startX, int startY, int endX, int endY) =>
      terminal.selectColumns(startX, startY, endX, endY);

  /// Returns whether [coordinates] lies in the half-open [start], [end] range.
  static bool areCoordinatesInSelection(
    TerminalBufferPosition coordinates,
    TerminalBufferPosition start,
    TerminalBufferPosition end,
  ) =>
      coordinates.y > start.y && coordinates.y < end.y ||
      start.y == end.y &&
          coordinates.y == start.y &&
          coordinates.x >= start.x &&
          coordinates.x < end.x ||
      start.y < end.y && coordinates.y == end.y && coordinates.x < end.x ||
      start.y < end.y && coordinates.y == start.y && coordinates.x >= start.x;

  /// Applies xterm's precedence between mouse reporting and forced selection.
  static bool shouldForceSelection({
    required bool altKey,
    required bool shiftKey,
    required bool mouseEventsRequireAlt,
    required bool mouseEventsActive,
    required bool isMac,
    required bool macOptionClickForcesSelection,
  }) {
    if (mouseEventsRequireAlt && mouseEventsActive) return !altKey;
    if (isMac) return altKey && macOptionClickForcesSelection;
    return shiftKey;
  }

  /// Computes the word range at [position], following wrapped logical lines.
  TerminalBufferRange? wordRange(
    TerminalBufferPosition position, {
    required bool allowWhitespaceOnly,
  }) {
    final buffer = terminal.buffer.active;
    final line = buffer.getLine(position.y);
    if (line == null || position.x < 0 || position.x >= terminal.cols) {
      return null;
    }
    var column = position.x;
    while (column > 0 && line.getCell(column)?.width == 0) {
      column--;
    }
    final initial = line.getCell(column);
    if (initial == null) return null;
    final spaces = initial.chars == ' ';
    bool matches(TerminalCell? cell) {
      if (cell == null) return false;
      if (spaces) return cell.chars == ' ';
      if (cell.width == 0) return true;
      return !terminal.options.wordSeparator.contains(cell.chars);
    }

    var startRow = position.y;
    var startColumn = column;
    while (true) {
      if (startColumn > 0) {
        if (!matches(buffer.getLine(startRow)?.getCell(startColumn - 1))) break;
        startColumn--;
        continue;
      }
      final currentLine = buffer.getLine(startRow);
      if (spaces || startRow == 0 || !(currentLine?.isWrapped ?? false)) break;
      if (!matches(buffer.getLine(startRow - 1)?.getCell(terminal.cols - 1))) {
        break;
      }
      startRow--;
      startColumn = terminal.cols - 1;
    }
    var endRow = position.y;
    var endColumn = column;
    while (true) {
      if (endColumn + 1 < terminal.cols) {
        if (!matches(buffer.getLine(endRow)?.getCell(endColumn + 1))) break;
        endColumn++;
        continue;
      }
      final nextLine = buffer.getLine(endRow + 1);
      if (spaces ||
          nextLine == null ||
          !nextLine.isWrapped ||
          !matches(nextLine.getCell(0))) {
        break;
      }
      endRow++;
      endColumn = 0;
    }
    if (!allowWhitespaceOnly && (spaces || initial.chars.trim().isEmpty)) {
      return null;
    }
    return TerminalBufferRange(
      start: TerminalBufferPosition(startColumn, startRow),
      end: TerminalBufferPosition(endColumn + 1, endRow),
    );
  }

  /// Computes the complete wrapped logical-line range containing [row].
  TerminalBufferRange? wrappedLineRange(int row) {
    final buffer = terminal.buffer.active;
    if (buffer.getLine(row) == null) return null;
    var first = row;
    while (first > 0 && (buffer.getLine(first)?.isWrapped ?? false)) {
      first--;
    }
    var last = row;
    while (last + 1 < buffer.length &&
        (buffer.getLine(last + 1)?.isWrapped ?? false)) {
      last++;
    }
    return TerminalBufferRange(
      start: TerminalBufferPosition(0, first),
      end: TerminalBufferPosition(terminal.cols, last),
    );
  }

  void _selectRange(TerminalBufferRange range) {
    final columns = terminal.cols;
    final start = range.start.y * columns + range.start.x;
    final end = range.end.y * columns + range.end.x;
    terminal.select(
      range.start.x,
      range.start.y,
      (end - start).clamp(0, 0x7fffffff),
    );
  }
}
