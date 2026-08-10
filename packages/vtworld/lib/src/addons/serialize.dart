/// ANSI and HTML terminal serialization addon.
library;

import 'package:vtworld/src/addons/managed_addon.dart';
import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/marker.dart';
import 'package:vtworld/src/core/options.dart';
import 'package:vtworld/src/core/terminal.dart';

/// Inclusive line range used for ANSI serialization.
final class TerminalSerializeRange {
  /// xterm-compatible `TerminalSerializeRange` API.
  const TerminalSerializeRange({required this.start, required this.end});

  /// xterm-compatible `start` API.
  final Object start;

  /// xterm-compatible `end` API.
  final Object end;
}

/// ANSI serialization controls.
final class TerminalSerializeOptions {
  /// xterm-compatible `TerminalSerializeOptions` API.
  const TerminalSerializeOptions({
    this.range,
    this.scrollback,
    this.excludeModes = false,
    this.excludeAltBuffer = false,
  });

  /// xterm-compatible `range` API.
  final TerminalSerializeRange? range;

  /// xterm-compatible `scrollback` API.
  final int? scrollback;

  /// xterm-compatible `excludeModes` API.
  final bool excludeModes;

  /// xterm-compatible `excludeAltBuffer` API.
  final bool excludeAltBuffer;
}

/// HTML serialization controls.
final class TerminalHtmlSerializeOptions {
  /// xterm-compatible `TerminalHtmlSerializeOptions` API.
  const TerminalHtmlSerializeOptions({
    this.scrollback,
    this.onlySelection = false,
    this.includeGlobalBackground = false,
    this.range,
  });

  /// xterm-compatible `scrollback` API.
  final int? scrollback;

  /// xterm-compatible `onlySelection` API.
  final bool onlySelection;

  /// xterm-compatible `includeGlobalBackground` API.
  final bool includeGlobalBackground;

  /// Explicit active-buffer range. It takes priority over [onlySelection].
  final TerminalHtmlSerializeRange? range;
}

/// Active-buffer range used by HTML serialization.
final class TerminalHtmlSerializeRange {
  /// Creates an inclusive row range starting at [startColumn].
  const TerminalHtmlSerializeRange({
    required this.startLine,
    required this.endLine,
    this.startColumn = 0,
  });

  /// First row to serialize.
  final int startLine;

  /// Last row to serialize.
  final int endLine;

  /// First column on [startLine].
  final int startColumn;
}

/// Serializes the current buffer so it can be restored or copied.
final class SerializeAddon extends ManagedTerminalAddon {
  @override
  void onActivate(Terminal terminal) {}

  /// Serializes visible and retained rows as ANSI text.
  String serialize({
    TerminalSerializeOptions options = const TerminalSerializeOptions(),
  }) {
    final normal = terminal.buffer.normal;
    final range = _lineRange(normal, options.range, options.scrollback);
    final result = StringBuffer()
      ..write(
        _StringSerializeHandler(normal, terminal, this).serialize(
          range.$1,
          range.$2,
          excludeFinalCursorPosition: options.range != null,
        ),
      );
    if (!options.excludeAltBuffer &&
        identical(terminal.buffer.active, terminal.buffer.alternate)) {
      result.write('\u001b[?1049h\u001b[H');
      final alternate = terminal.buffer.alternate;
      result.write(
        _StringSerializeHandler(
          alternate,
          terminal,
          this,
        ).serialize(0, alternate.length - 1),
      );
    }
    if (!options.excludeModes) _serializeModes(result);
    return result.toString();
  }

  /// Serializes the active buffer or current selection as safe HTML.
  String serializeAsHtml({
    TerminalHtmlSerializeOptions options = const TerminalHtmlSerializeOptions(),
  }) {
    final buffer = terminal.buffer.active;
    late final TerminalBufferPosition start;
    late final TerminalBufferPosition end;
    final requested = options.range;
    if (requested != null) {
      start = TerminalBufferPosition(
        requested.startColumn,
        requested.startLine,
      );
      end = TerminalBufferPosition(terminal.cols, requested.endLine);
    } else if (options.onlySelection) {
      final selection = terminal.getSelectionPosition();
      if (selection == null) return '';
      start = selection.start;
      end = selection.end;
    } else {
      final rows = options.scrollback == null
          ? buffer.length
          : (options.scrollback! + terminal.rows).clamp(0, buffer.length);
      start = TerminalBufferPosition(0, buffer.length - rows);
      end = TerminalBufferPosition(terminal.cols, buffer.length - 1);
    }
    if (start.y < 0 || end.y < start.y || end.y >= buffer.length) {
      throw RangeError('HTML serialization range is outside the active buffer');
    }

    final theme = terminal.options.theme;
    final foreground = options.includeGlobalBackground
        ? theme.foreground ?? '#ffffff'
        : '#000000';
    final background = options.includeGlobalBackground
        ? theme.background ?? '#000000'
        : '#ffffff';
    final output = StringBuffer()
      ..write('<html><body><!--StartFragment--><pre>')
      ..write("<div style='color: $foreground; ")
      ..write('background-color: $background; ')
      ..write('font-family: ${terminal.options.fontFamily}; ')
      ..write("font-size: ${_cssNumber(terminal.options.fontSize)}px;'>");
    final palette = _ansiPalette(theme);
    final empty = buffer.getNullCell();
    for (var row = start.y; row <= end.y; row++) {
      final line = buffer.getLine(row)!;
      final firstColumn = row == start.y ? start.x.clamp(0, line.length) : 0;
      final lastColumn = row == end.y
          ? end.x.clamp(0, line.length)
          : line.length;
      var previous = empty;
      output.write('<div><span>');
      for (var column = firstColumn; column < lastColumn; column++) {
        final cell = line.getCell(column)!;
        if (cell.width == 0) continue;
        if (!cell.attributesEqual(previous)) {
          final styles = _htmlStyles(cell, palette);
          output
            ..write('</span><span')
            ..write(styles.isEmpty ? '>' : " style='${styles.join(' ')}'>");
        }
        output.write(cell.chars.isEmpty ? ' ' : _escapeHtmlCell(cell.chars));
        previous = cell;
      }
      output.write('</span></div>');
    }
    return '$output</div></pre><!--EndFragment--></body></html>';
  }

  String _cssNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  String _escapeHtmlCell(String value) =>
      value.replaceAll('&', '&amp;').replaceAll('<', '&lt;');

  List<String> _htmlStyles(TerminalCell cell, List<String> palette) {
    final styles = <String>[];
    final foreground = _htmlColor(
      cell.foregroundMode,
      cell.foreground,
      palette,
    );
    if (foreground != null) styles.add('color: $foreground;');
    final background = _htmlColor(
      cell.backgroundMode,
      cell.background,
      palette,
    );
    if (background != null) styles.add('background-color: $background;');
    if (cell.isInverse) {
      styles.add('color: #000000; background-color: #BFBFBF;');
    }
    if (cell.isBold) styles.add('font-weight: bold;');
    final decorations = <String>[];
    if (cell.isUnderline) {
      decorations.add(switch (cell.underlineStyle) {
        TerminalUnderlineStyle.double => 'underline double',
        TerminalUnderlineStyle.curly => 'underline wavy',
        TerminalUnderlineStyle.dotted => 'underline dotted',
        TerminalUnderlineStyle.dashed => 'underline dashed',
        _ => 'underline',
      });
    }
    if (cell.isOverline) decorations.add('overline');
    if (cell.isStrikethrough) decorations.add('line-through');
    if (cell.isBlink) decorations.add('blink');
    if (decorations.isNotEmpty) {
      styles.add('text-decoration: ${decorations.join(' ')};');
    }
    if (cell.isUnderline) {
      final underline = _htmlColor(
        cell.underlineColor.mode,
        cell.underlineColor.value,
        palette,
      );
      if (underline != null) styles.add('text-decoration-color: $underline;');
    }
    if (cell.isInvisible) styles.add('visibility: hidden;');
    if (cell.isItalic) styles.add('font-style: italic;');
    if (cell.isDim) styles.add('opacity: 0.5;');
    return styles;
  }

  String? _htmlColor(TerminalColorMode mode, int value, List<String> palette) =>
      switch (mode) {
        TerminalColorMode.defaultColor => null,
        TerminalColorMode.palette => palette[value.clamp(0, 255)],
        TerminalColorMode.rgb =>
          '#${value.toRadixString(16).padLeft(6, '0').substring(0, 6)}',
      };

  List<String> _ansiPalette(TerminalColorTheme theme) {
    final colors = <String>[
      '#2e3436',
      '#cc0000',
      '#4e9a06',
      '#c4a000',
      '#3465a4',
      '#75507b',
      '#06989a',
      '#d3d7cf',
      '#555753',
      '#ef2929',
      '#8ae234',
      '#fce94f',
      '#729fcf',
      '#ad7fa8',
      '#34e2e2',
      '#eeeeec',
    ];
    const levels = <int>[0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff];
    for (var index = 0; index < 216; index++) {
      colors.add(
        _rgb(
          levels[index ~/ 36 % 6],
          levels[index ~/ 6 % 6],
          levels[index % 6],
        ),
      );
    }
    for (var index = 0; index < 24; index++) {
      final value = 8 + index * 10;
      colors.add(_rgb(value, value, value));
    }
    final overrides = <String?>[
      theme.black,
      theme.red,
      theme.green,
      theme.yellow,
      theme.blue,
      theme.magenta,
      theme.cyan,
      theme.white,
      theme.brightBlack,
      theme.brightRed,
      theme.brightGreen,
      theme.brightYellow,
      theme.brightBlue,
      theme.brightMagenta,
      theme.brightCyan,
      theme.brightWhite,
    ];
    for (var index = 0; index < overrides.length; index++) {
      if (overrides[index] case final value?) colors[index] = value;
    }
    final extended = theme.extendedAnsi;
    if (extended != null) {
      for (var index = 0; index < extended.length && index < 240; index++) {
        colors[index + 16] = extended[index];
      }
    }
    return colors;
  }

  String _rgb(int red, int green, int blue) =>
      '#${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';

  (int, int) _lineRange(
    TerminalBuffer buffer,
    TerminalSerializeRange? requested,
    int? scrollback,
  ) {
    var start = 0;
    var end = buffer.length - 1;
    if (requested != null) {
      start = _line(requested.start);
      end = _line(requested.end);
    } else if (scrollback != null) {
      if (scrollback < 0) throw ArgumentError.value(scrollback, 'scrollback');
      start = (buffer.baseY - scrollback).clamp(0, end);
    }
    if (start < 0 || end < start || end >= buffer.length) {
      throw RangeError('Serialization range is outside the active buffer');
    }
    return (start, end);
  }

  int _line(Object value) => switch (value) {
    final int line => line,
    final TerminalMarker marker => marker.line,
    _ => throw ArgumentError.value(value, 'range', 'must use marker or int'),
  };

  List<String> _sgrDiff(TerminalCell cell, TerminalCell previous) {
    if (cell.attributesEqual(previous)) return const <String>[];
    if (cell.isAttributeDefault && !previous.isAttributeDefault) {
      return const <String>['0'];
    }
    final codes = <String>[];
    if (cell.foregroundMode != previous.foregroundMode ||
        cell.foreground != previous.foreground) {
      _appendAnsiColor(
        codes,
        cell.foregroundMode,
        cell.foreground,
        foreground: true,
      );
    }
    if (cell.backgroundMode != previous.backgroundMode ||
        cell.background != previous.background) {
      _appendAnsiColor(
        codes,
        cell.backgroundMode,
        cell.background,
        foreground: false,
      );
    }
    if (cell.isInverse != previous.isInverse) {
      codes.add(cell.isInverse ? '7' : '27');
    }
    if (cell.isBold != previous.isBold) {
      codes.add(cell.isBold ? '1' : '22');
    }
    final storedUnderline = cell.copyAttributes().underlineColor;
    final previousStoredUnderline = previous.copyAttributes().underlineColor;
    final underlineChanged =
        cell.underlineStyle != previous.underlineStyle ||
        cell.isUnderline &&
            previous.isUnderline &&
            storedUnderline != previousStoredUnderline;
    if (underlineChanged) {
      if (!cell.isUnderline) {
        codes.add('24');
      } else if (cell.underlineStyle == TerminalUnderlineStyle.single &&
          storedUnderline.mode == TerminalColorMode.defaultColor) {
        codes.add('4');
      } else {
        codes.add('4:${cell.underlineStyle.index}');
        final underline = storedUnderline;
        if (underline.mode == TerminalColorMode.rgb) {
          codes.add(
            '58:2::${underline.red}:${underline.green}:${underline.blue}',
          );
        } else if (underline.mode == TerminalColorMode.palette) {
          codes.add('58:5:${underline.value}');
        }
      }
    }
    if (cell.isOverline != previous.isOverline) {
      codes.add(cell.isOverline ? '53' : '55');
    }
    if (cell.isBlink != previous.isBlink) {
      codes.add(cell.isBlink ? '5' : '25');
    }
    if (cell.isInvisible != previous.isInvisible) {
      codes.add(cell.isInvisible ? '8' : '28');
    }
    if (cell.isItalic != previous.isItalic) {
      codes.add(cell.isItalic ? '3' : '23');
    }
    if (cell.isDim != previous.isDim) {
      codes.add(cell.isDim ? '2' : '22');
    }
    if (cell.isStrikethrough != previous.isStrikethrough) {
      codes.add(cell.isStrikethrough ? '9' : '29');
    }
    return codes;
  }

  void _appendAnsiColor(
    List<String> output,
    TerminalColorMode mode,
    int color, {
    required bool foreground,
  }) {
    switch (mode) {
      case TerminalColorMode.defaultColor:
        output.add(foreground ? '39' : '49');
      case TerminalColorMode.palette:
        if (color >= 16) {
          final selector = foreground ? '38' : '48';
          output.addAll(<String>[selector, '5', '$color']);
        } else {
          final base = foreground
              ? (color & 8) != 0
                    ? 90
                    : 30
              : (color & 8) != 0
              ? 100
              : 40;
          output.add('${base + (color & 7)}');
        }
      case TerminalColorMode.rgb:
        final selector = foreground ? '38' : '48';
        output.addAll(<String>[
          selector,
          '2',
          '${color >> 16 & 255}',
          '${color >> 8 & 255}',
          '${color & 255}',
        ]);
    }
  }

  void _serializeModes(StringBuffer result) {
    final modes = terminal.modes;
    if (modes.applicationCursorKeysMode) result.write('\u001b[?1h');
    if (modes.applicationKeypadMode) result.write('\u001b[?66h');
    if (modes.bracketedPasteMode) result.write('\u001b[?2004h');
    if (modes.insertMode) result.write('\u001b[4h');
    if (modes.originMode) result.write('\u001b[?6h');
    if (modes.reverseWraparoundMode) result.write('\u001b[?45h');
    if (modes.sendFocusMode) result.write('\u001b[?1004h');
    if (!modes.showCursor) result.write('\u001b[?25l');
    if (!modes.wraparoundMode) result.write('\u001b[?7l');
    switch (modes.mouseTrackingMode) {
      case 'x10':
        result.write('\u001b[?9h');
      case 'vt200':
        result.write('\u001b[?1000h');
      case 'drag':
        result.write('\u001b[?1002h');
      case 'any':
        result.write('\u001b[?1003h');
      case 'none':
        break;
    }
    if (modes.scrollTop != 0 || modes.scrollBottom != terminal.rows - 1) {
      result.write('\u001b[${modes.scrollTop + 1};${modes.scrollBottom + 1}r');
    }
  }
}

final class _StringSerializeHandler {
  _StringSerializeHandler(this.buffer, this.terminal, this.addon)
    : _cursorStyle = buffer.getNullCell(),
      _backgroundCell = buffer.getNullCell(),
      _thisRowLastChar = buffer.getNullCell(),
      _thisRowLastSecondChar = buffer.getNullCell(),
      _nextRowFirstChar = buffer.getNullCell();

  final TerminalBuffer buffer;
  final Terminal terminal;
  final SerializeAddon addon;
  final TerminalCell _cursorStyle;
  final TerminalCell _backgroundCell;
  final TerminalCell _thisRowLastChar;
  final TerminalCell _thisRowLastSecondChar;
  final TerminalCell _nextRowFirstChar;
  final List<String> _rows = <String>[];
  final List<String> _separators = <String>[];
  var _currentRow = StringBuffer();
  var _nullCellCount = 0;
  var _cursorStyleRow = 0;
  var _cursorStyleColumn = 0;
  var _firstRow = 0;
  var _lastCursorRow = 0;
  var _lastCursorColumn = 0;
  var _lastContentCursorRow = 0;
  var _lastContentCursorColumn = 0;

  String serialize(
    int startRow,
    int endRow, {
    bool excludeFinalCursorPosition = false,
  }) {
    _firstRow = startRow;
    _lastCursorRow = startRow;
    _lastContentCursorRow = startRow;
    for (var row = startRow; row <= endRow; row++) {
      final line = buffer.getLine(row)!;
      for (var column = 0; column < line.length; column++) {
        _nextCell(line.getCell(column)!, row, column);
      }
      _rowEnd(row, row == endRow);
    }
    return _serializeString(excludeFinalCursorPosition);
  }

  void _nextCell(TerminalCell cell, int row, int column) {
    if (cell.width == 0) return;
    final isEmpty = cell.chars.isEmpty;
    final sgr = addon._sgrDiff(cell, _cursorStyle);
    final styleChanged = isEmpty
        ? !_backgroundEqual(_cursorStyle, cell)
        : sgr.isNotEmpty;
    if (styleChanged) {
      _flushNullCells();
      _lastContentCursorRow = _lastCursorRow = row;
      _lastContentCursorColumn = _lastCursorColumn = column;
      _currentRow.write('\u001b[${sgr.join(';')}m');
      buffer.getLine(row)!.getCell(column, _cursorStyle);
      _cursorStyleRow = row;
      _cursorStyleColumn = column;
    }
    if (isEmpty) {
      _nullCellCount += cell.width;
      return;
    }
    if (_nullCellCount > 0) {
      if (_backgroundEqual(_cursorStyle, _backgroundCell)) {
        _currentRow.write('\u001b[${_nullCellCount}C');
      } else {
        _currentRow
          ..write('\u001b[${_nullCellCount}X')
          ..write('\u001b[${_nullCellCount}C');
      }
      _nullCellCount = 0;
    }
    _currentRow.write(cell.chars);
    _lastContentCursorRow = _lastCursorRow = row;
    _lastContentCursorColumn = _lastCursorColumn = column + cell.width;
  }

  void _flushNullCells() {
    if (_nullCellCount == 0) return;
    if (!_backgroundEqual(_cursorStyle, _backgroundCell)) {
      _currentRow.write('\u001b[${_nullCellCount}X');
    }
    _currentRow.write('\u001b[${_nullCellCount}C');
    _nullCellCount = 0;
  }

  void _rowEnd(int row, bool isLastRow) {
    if (_nullCellCount > 0 &&
        !_backgroundEqual(_cursorStyle, _backgroundCell)) {
      _currentRow.write('\u001b[${_nullCellCount}X');
    }
    var separator = '';
    if (!isLastRow) {
      if (row - _firstRow >= terminal.rows) {
        buffer
            .getLine(_cursorStyleRow)
            ?.getCell(_cursorStyleColumn, _backgroundCell);
      }
      final currentLine = buffer.getLine(row)!;
      final nextLine = buffer.getLine(row + 1)!;
      if (!nextLine.isWrapped) {
        separator = '\r\n';
        _lastCursorRow = row + 1;
        _lastCursorColumn = 0;
      } else if (!_validWrap(currentLine, nextLine)) {
        separator = '${'-' * (_nullCellCount + 1)}\u001b[1D\u001b[1X';
        if (_nullCellCount > 0) {
          final contentColumns = currentLine.length - _nullCellCount;
          separator +=
              '\u001b[A\u001b[${contentColumns}C'
              '\u001b[${_nullCellCount}X'
              '\u001b[${contentColumns}D\u001b[B';
        }
        _lastContentCursorRow = _lastCursorRow = row + 1;
        _lastContentCursorColumn = _lastCursorColumn = 0;
      }
    }
    _rows.add(_currentRow.toString());
    _separators.add(separator);
    _currentRow = StringBuffer();
    _nullCellCount = 0;
  }

  bool _validWrap(TerminalBufferLine currentLine, TerminalBufferLine nextLine) {
    final last = currentLine.getCell(currentLine.length - 1, _thisRowLastChar)!;
    final secondLast = currentLine.getCell(
      currentLine.length - 2,
      _thisRowLastSecondChar,
    )!;
    final next = nextLine.getCell(0, _nextRowFirstChar)!;
    final doubleWidth = next.width > 1;
    if (next.chars.isEmpty ||
        (doubleWidth ? _nullCellCount > 1 : _nullCellCount > 0)) {
      return false;
    }
    if ((last.chars.isNotEmpty || last.width == 0) &&
        _backgroundEqual(last, next)) {
      return true;
    }
    return doubleWidth &&
        (secondLast.chars.isNotEmpty || secondLast.width == 0) &&
        _backgroundEqual(last, next) &&
        _backgroundEqual(secondLast, next);
  }

  String _serializeString(bool excludeFinalCursorPosition) {
    var rowEnd = _rows.length;
    if (buffer.length - _firstRow <= terminal.rows) {
      rowEnd = _lastContentCursorRow + 1 - _firstRow;
      _lastCursorColumn = _lastContentCursorColumn;
      _lastCursorRow = _lastContentCursorRow;
    }
    final output = StringBuffer();
    for (var index = 0; index < rowEnd; index++) {
      output.write(_rows[index]);
      if (index + 1 < rowEnd) output.write(_separators[index]);
    }
    if (!excludeFinalCursorPosition) {
      _moveVertical(output, buffer.absoluteCursorY - _lastCursorRow);
      _moveHorizontal(output, buffer.cursorX - _lastCursorColumn);
    }
    final current = TerminalBufferLine(
      1,
      attributes: terminal.currentAttributes,
    ).getCell(0)!;
    final sgr = addon._sgrDiff(current, _cursorStyle);
    if (sgr.isNotEmpty) output.write('\u001b[${sgr.join(';')}m');
    return output.toString();
  }

  void _moveHorizontal(StringBuffer output, int offset) {
    if (offset > 0) output.write('\u001b[${offset}C');
    if (offset < 0) output.write('\u001b[${-offset}D');
  }

  void _moveVertical(StringBuffer output, int offset) {
    if (offset > 0) output.write('\u001b[${offset}B');
    if (offset < 0) output.write('\u001b[${-offset}A');
  }

  bool _backgroundEqual(TerminalCell left, TerminalCell right) =>
      left.backgroundMode == right.backgroundMode &&
      left.background == right.background;
}
