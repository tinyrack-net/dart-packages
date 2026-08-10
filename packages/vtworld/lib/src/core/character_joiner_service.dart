import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/terminal.dart';

/// Cell-like data produced for a single joined rendering unit.
final class JoinedCellData {
  /// Creates joined data using attributes from [firstCell].
  const JoinedCellData(this.firstCell, this.chars, this.width);

  /// First cell whose renderer attributes apply to the joined text.
  final TerminalCell firstCell;

  /// Combined UTF-16 text.
  final String chars;

  /// Combined width in terminal cells.
  final int width;

  /// Sentinel code point used by xterm renderer caches.
  int get code => 0x1fffff;

  /// Joined cells are always represented as combined data.
  bool get isCombined => true;
}

/// Applies registered ligature joiners to styled terminal buffer lines.
final class CharacterJoinerService {
  /// Creates a joiner service over [bufferNamespace].
  CharacterJoinerService(TerminalBufferNamespace bufferNamespace)
    : _buffers = bufferNamespace;

  final TerminalBufferNamespace _buffers;
  final List<_CharacterJoiner> _characterJoiners = <_CharacterJoiner>[];
  int _nextCharacterJoinerId = 0;

  /// Registers [handler] and returns its monotonically increasing identifier.
  int register(TerminalCharacterJoiner handler) {
    final joiner = _CharacterJoiner(_nextCharacterJoinerId++, handler);
    _characterJoiners.add(joiner);
    return joiner.id;
  }

  /// Removes a joiner, returning whether it existed.
  bool deregister(int joinerId) {
    final index = _characterJoiners.indexWhere(
      (joiner) => joiner.id == joinerId,
    );
    if (index == -1) return false;
    _characterJoiners.removeAt(index);
    return true;
  }

  /// Returns joined cell-column ranges on absolute buffer [row].
  List<TerminalCharacterJoin> getJoinedCharacters(int row) {
    if (_characterJoiners.isEmpty) return <TerminalCharacterJoin>[];
    final line = _buffers.active.getLine(row);
    if (line == null || line.length == 0) return <TerminalCharacterJoin>[];
    final trimmedLength = _trimmedLength(line);
    if (trimmedLength == 0) return <TerminalCharacterJoin>[];
    final lineString = line.translateToString(trimRight: true);
    final ranges = <TerminalCharacterJoin>[];
    var rangeStartColumn = 0;
    var currentStringIndex = 0;
    var rangeStartStringIndex = 0;
    final firstCell = line.getCell(0)!;
    var rangeForeground = firstCell.foreground;
    var rangeBackground = firstCell.background;
    for (var column = 0; column < trimmedLength; column++) {
      final cell = line.getCell(column)!;
      if (cell.width == 0) continue;
      if (cell.foreground != rangeForeground ||
          cell.background != rangeBackground) {
        if (column - rangeStartColumn > 1) {
          ranges.addAll(
            _getJoinedRanges(
              lineString,
              rangeStartStringIndex,
              currentStringIndex,
              line,
              rangeStartColumn,
            ),
          );
        }
        rangeStartColumn = column;
        rangeStartStringIndex = currentStringIndex;
        rangeForeground = cell.foreground;
        rangeBackground = cell.background;
      }
      currentStringIndex += cell.chars.isEmpty ? 1 : cell.chars.length;
    }
    if (trimmedLength - rangeStartColumn > 1) {
      ranges.addAll(
        _getJoinedRanges(
          lineString,
          rangeStartStringIndex,
          currentStringIndex,
          line,
          rangeStartColumn,
        ),
      );
    }
    return ranges;
  }

  List<TerminalCharacterJoin> _getJoinedRanges(
    String line,
    int startIndex,
    int endIndex,
    TerminalBufferLine lineData,
    int startColumn,
  ) {
    final text = line.substring(startIndex, endIndex);
    var ranges = <TerminalCharacterJoin>[];
    try {
      ranges = _characterJoiners.first.handler(text);
    } on Object {
      ranges = <TerminalCharacterJoin>[];
    }
    for (var index = 1; index < _characterJoiners.length; index++) {
      try {
        final additional = _characterJoiners[index].handler(text);
        for (final range in additional) {
          _mergeRanges(ranges, range);
        }
      } on Object {
        // A faulty browser joiner must not prevent terminal rendering.
      }
    }
    _stringRangesToCellRanges(ranges, lineData, startColumn);
    return ranges;
  }

  static void _stringRangesToCellRanges(
    List<TerminalCharacterJoin> ranges,
    TerminalBufferLine line,
    int startColumn,
  ) {
    if (ranges.isEmpty) return;
    var rangeIndex = 0;
    var rangeStarted = false;
    var stringIndex = 0;
    var current = ranges[rangeIndex];
    final trimmedLength = _trimmedLength(line);
    for (var column = startColumn; column < trimmedLength; column++) {
      final cell = line.getCell(column)!;
      if (cell.width == 0) continue;
      if (!rangeStarted && current.start <= stringIndex) {
        current = TerminalCharacterJoin(column, current.end);
        ranges[rangeIndex] = current;
        rangeStarted = true;
      }
      if (current.end <= stringIndex) {
        ranges[rangeIndex] = TerminalCharacterJoin(current.start, column);
        rangeIndex++;
        if (rangeIndex >= ranges.length) return;
        current = ranges[rangeIndex];
        if (current.start <= stringIndex) {
          current = TerminalCharacterJoin(column, current.end);
          ranges[rangeIndex] = current;
          rangeStarted = true;
        } else {
          rangeStarted = false;
        }
      }
      stringIndex += cell.chars.isEmpty ? 1 : cell.chars.length;
    }
    ranges[rangeIndex] = TerminalCharacterJoin(current.start, trimmedLength);
  }

  static List<TerminalCharacterJoin> _mergeRanges(
    List<TerminalCharacterJoin> ranges,
    TerminalCharacterJoin newRange,
  ) {
    var inRange = false;
    for (var index = 0; index < ranges.length; index++) {
      final range = ranges[index];
      if (!inRange) {
        if (newRange.end <= range.start) {
          ranges.insert(index, newRange);
          return ranges;
        }
        if (newRange.end <= range.end) {
          ranges[index] = TerminalCharacterJoin(
            newRange.start < range.start ? newRange.start : range.start,
            range.end,
          );
          return ranges;
        }
        if (newRange.start < range.end) {
          ranges[index] = TerminalCharacterJoin(
            newRange.start < range.start ? newRange.start : range.start,
            range.end,
          );
          inRange = true;
        }
        continue;
      }
      if (newRange.end <= range.start) {
        final previous = ranges[index - 1];
        ranges[index - 1] = TerminalCharacterJoin(previous.start, newRange.end);
        return ranges;
      }
      if (newRange.end <= range.end) {
        final previous = ranges[index - 1];
        ranges[index - 1] = TerminalCharacterJoin(
          previous.start,
          newRange.end > range.end ? newRange.end : range.end,
        );
        ranges.removeAt(index);
        return ranges;
      }
      ranges.removeAt(index--);
    }
    if (inRange) {
      final last = ranges.last;
      ranges[ranges.length - 1] = TerminalCharacterJoin(
        last.start,
        newRange.end,
      );
    } else {
      ranges.add(newRange);
    }
    return ranges;
  }

  static int _trimmedLength(TerminalBufferLine line) {
    for (var column = line.length - 1; column >= 0; column--) {
      final cell = line.getCell(column)!;
      if (cell.width == 0 || cell.chars.isNotEmpty) return column + 1;
    }
    return 0;
  }
}

final class _CharacterJoiner {
  const _CharacterJoiner(this.id, this.handler);

  final int id;
  final TerminalCharacterJoiner handler;
}
