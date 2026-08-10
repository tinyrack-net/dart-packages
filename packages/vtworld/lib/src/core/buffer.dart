import 'package:vtworld/src/core/buffer_line_string_cache.dart';
import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';
import 'package:vtworld/src/core/marker.dart';
import 'package:vtworld/src/core/options.dart';

/// Terminal buffer kind.
enum TerminalBufferType {
  /// The normal buffer with scrollback history.
  normal,

  /// The alternate screen buffer without scrollback history.
  alternate,
}

/// Encoded terminal color kind.
enum TerminalColorMode {
  /// The terminal's configured default color.
  defaultColor,

  /// An indexed color from the ANSI 256-color palette.
  palette,

  /// A 24-bit red, green and blue color.
  rgb,
}

/// Underline rendering style.
enum TerminalUnderlineStyle {
  /// No underline.
  none,

  /// A single straight underline.
  single,

  /// A double straight underline.
  double,

  /// A curly underline.
  curly,

  /// A dotted underline.
  dotted,

  /// A dashed underline.
  dashed,
}

/// An immutable position in the backing buffer.
final class TerminalBufferPosition {
  /// Creates a zero-based buffer position.
  const TerminalBufferPosition(this.x, this.y);

  /// Zero-based column.
  final int x;

  /// Zero-based absolute buffer row.
  final int y;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      other is TerminalBufferPosition && other.x == x && other.y == y;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'TerminalBufferPosition($x, $y)';
}

/// An inclusive terminal buffer range.
final class TerminalBufferRange {
  /// Creates an inclusive range from [start] through [end].
  const TerminalBufferRange({required this.start, required this.end});

  /// First selected cell.
  final TerminalBufferPosition start;

  /// Last selected cell.
  final TerminalBufferPosition end;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      other is TerminalBufferRange && other.start == start && other.end == end;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TerminalBufferRange(start: $start, end: $end)';
}

/// A structural change to the buffer's logical line collection.
final class TerminalBufferLineChange {
  /// Creates a line change at [index] affecting [amount] lines.
  const TerminalBufferLineChange({required this.index, required this.amount});

  /// Absolute buffer line where the change begins.
  final int index;

  /// Number of inserted or deleted lines.
  final int amount;
}

/// A color encoded exactly as xterm's default, indexed or RGB color.
final class TerminalCellColor {
  /// Creates the configured default color.
  const TerminalCellColor.defaultColor()
    : mode = TerminalColorMode.defaultColor,
      value = 0;

  /// Creates an ANSI palette color with [index].
  const TerminalCellColor.palette(int index)
    : mode = TerminalColorMode.palette,
      value = index;

  /// Creates a 24-bit color from its component values.
  const TerminalCellColor.rgb(int red, int green, int blue)
    : mode = TerminalColorMode.rgb,
      value = red << 16 | green << 8 | blue;

  /// Encoding used by [value].
  final TerminalColorMode mode;

  /// Palette index or packed `0xRRGGBB` value.
  final int value;

  /// Red component of an RGB color.
  int get red => value >> 16 & 0xff;

  /// Green component of an RGB color.
  int get green => value >> 8 & 0xff;

  /// Blue component of an RGB color.
  int get blue => value & 0xff;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      other is TerminalCellColor && other.mode == mode && other.value == value;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(mode, value);
}

/// Mutable cell attributes used internally by the input handler.
final class TerminalCellAttributes {
  /// Creates a mutable set of terminal cell attributes.
  TerminalCellAttributes({
    this.foreground = const TerminalCellColor.defaultColor(),
    this.background = const TerminalCellColor.defaultColor(),
    this.underlineColor = const TerminalCellColor.defaultColor(),
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = TerminalUnderlineStyle.none,
    this.blink = false,
    this.inverse = false,
    this.invisible = false,
    this.strikethrough = false,
    this.overline = false,
    this.protected = false,
    this.hyperlinkId = 0,
    this.underlineVariantOffset = 0,
    this.imageId = -1,
    this.imageTileId = -1,
    bool? hasExtendedAttributes,
  }) : hasExtendedAttributes =
           hasExtendedAttributes ??
           (underline != TerminalUnderlineStyle.none ||
               underlineColor.mode != TerminalColorMode.defaultColor ||
               hyperlinkId != 0);

  /// Foreground color.
  TerminalCellColor foreground;

  /// Background color.
  TerminalCellColor background;

  /// Underline color.
  TerminalCellColor underlineColor;

  /// Whether bold intensity is enabled.
  bool bold;

  /// Whether faint intensity is enabled.
  bool dim;

  /// Whether italic rendering is enabled.
  bool italic;

  /// Underline style.
  TerminalUnderlineStyle underline;

  /// Whether blinking is enabled.
  bool blink;

  /// Whether foreground and background are inverted.
  bool inverse;

  /// Whether the cell content is hidden.
  bool invisible;

  /// Whether strikethrough is enabled.
  bool strikethrough;

  /// Whether overline is enabled.
  bool overline;

  /// Whether selective erase protects the cell.
  bool protected;

  /// Internal numeric identity assigned to an OSC 8 hyperlink.
  int hyperlinkId;

  /// Vertical underline variant offset encoded by xterm in extended attrs.
  int underlineVariantOffset;

  /// Internal image-storage identity carried by this cell.
  int imageId;

  /// Tile index within the image identified by [imageId].
  int imageTileId;

  /// Whether xterm's `HAS_EXTENDED` storage flag is active.
  ///
  /// The raw underline color can outlive this flag when underline styling is
  /// disabled. Public color access falls back to the foreground while the
  /// flag is inactive.
  bool hasExtendedAttributes;

  /// Recomputes xterm's extended-attribute storage flag after parser changes.
  void updateExtendedAttributes() {
    hasExtendedAttributes =
        underline != TerminalUnderlineStyle.none || hyperlinkId != 0;
  }

  /// Returns an independent copy of these attributes.
  TerminalCellAttributes copy() => TerminalCellAttributes(
    foreground: foreground,
    background: background,
    underlineColor: underlineColor,
    bold: bold,
    dim: dim,
    italic: italic,
    underline: underline,
    blink: blink,
    inverse: inverse,
    invisible: invisible,
    strikethrough: strikethrough,
    overline: overline,
    protected: protected,
    hyperlinkId: hyperlinkId,
    underlineVariantOffset: underlineVariantOffset,
    imageId: imageId,
    imageTileId: imageTileId,
    hasExtendedAttributes: hasExtendedAttributes,
  );

  /// Whether every observable attribute equals [other].
  bool sameAs(TerminalCellAttributes other) =>
      foreground == other.foreground &&
      background == other.background &&
      underlineColor == other.underlineColor &&
      bold == other.bold &&
      dim == other.dim &&
      italic == other.italic &&
      underline == other.underline &&
      blink == other.blink &&
      inverse == other.inverse &&
      invisible == other.invisible &&
      strikethrough == other.strikethrough &&
      overline == other.overline &&
      protected == other.protected &&
      hyperlinkId == other.hyperlinkId &&
      underlineVariantOffset == other.underlineVariantOffset &&
      hasExtendedAttributes == other.hasExtendedAttributes;
}

final class _CellData {
  _CellData({
    this.chars = '',
    this.width = 1,
    TerminalCellAttributes? attributes,
  }) : attributes = attributes?.copy() ?? TerminalCellAttributes();

  String chars;
  int width;
  TerminalCellAttributes attributes;

  int get code {
    final units = chars.codeUnits;
    if (units.isEmpty) return 0;
    if (units.length == 2 &&
        units[0] >= 0xd800 &&
        units[0] <= 0xdbff &&
        units[1] >= 0xdc00 &&
        units[1] <= 0xdfff) {
      return (units[0] - 0xd800) * 0x400 + units[1] - 0xdc00 + 0x10000;
    }
    return units.last;
  }

  _CellData copy() =>
      _CellData(chars: chars, width: width, attributes: attributes);

  void reset(TerminalCellAttributes value) {
    chars = '';
    width = 1;
    attributes = value.copy();
  }
}

/// Public read-only view of one terminal cell.
final class TerminalCell {
  TerminalCell._(this._cell);

  final _CellData _cell;

  /// Display width in terminal columns.
  int get width => _cell.width;

  /// Grapheme content, empty for a wide-character continuation cell.
  String get chars => width == 0 ? '' : _cell.chars;

  /// Last Unicode code point in [chars], or zero for an empty cell.
  int get code => _cell.code;

  /// Encoded foreground palette index or RGB value.
  int get foreground => _cell.attributes.foreground.value;

  /// Encoded background palette index or RGB value.
  int get background => _cell.attributes.background.value;

  /// Foreground color encoding.
  TerminalColorMode get foregroundMode => _cell.attributes.foreground.mode;

  /// Background color encoding.
  TerminalColorMode get backgroundMode => _cell.attributes.background.mode;

  /// Whether the foreground is encoded as a 24-bit RGB value.
  bool get isForegroundRgb => foregroundMode == TerminalColorMode.rgb;

  /// Whether the background is encoded as a 24-bit RGB value.
  bool get isBackgroundRgb => backgroundMode == TerminalColorMode.rgb;

  /// Whether the foreground is encoded as an ANSI palette index.
  bool get isForegroundPalette => foregroundMode == TerminalColorMode.palette;

  /// Whether the background is encoded as an ANSI palette index.
  bool get isBackgroundPalette => backgroundMode == TerminalColorMode.palette;

  /// Whether the terminal's default foreground color is used.
  bool get isForegroundDefault =>
      foregroundMode == TerminalColorMode.defaultColor;

  /// Whether the terminal's default background color is used.
  bool get isBackgroundDefault =>
      backgroundMode == TerminalColorMode.defaultColor;

  /// Color used to draw an underline.
  ///
  /// xterm retains the raw extended color when underline styling is disabled,
  /// but hides that value until extended attributes become active again. Its
  /// public cell API therefore falls back to the foreground in that state.
  TerminalCellColor get underlineColor {
    final attributes = _cell.attributes;
    if (!attributes.hasExtendedAttributes ||
        attributes.underlineColor.mode == TerminalColorMode.defaultColor) {
      return attributes.foreground;
    }
    return attributes.underlineColor;
  }

  /// Packed underline palette index or RGB value.
  int get underlineColorValue => underlineColor.value;

  /// Underline color encoding.
  TerminalColorMode get underlineColorMode => underlineColor.mode;

  /// Whether the underline color is encoded as RGB.
  bool get isUnderlineColorRgb => underlineColorMode == TerminalColorMode.rgb;

  /// Whether the underline color is encoded as an ANSI palette index.
  bool get isUnderlineColorPalette =>
      underlineColorMode == TerminalColorMode.palette;

  /// Whether the terminal's default underline color is used.
  bool get isUnderlineColorDefault =>
      underlineColorMode == TerminalColorMode.defaultColor;

  /// Style used to draw an underline.
  TerminalUnderlineStyle get underlineStyle => _cell.attributes.underline;

  /// Whether bold intensity is enabled.
  bool get isBold => _cell.attributes.bold;

  /// Whether faint intensity is enabled.
  bool get isDim => _cell.attributes.dim;

  /// Whether italic rendering is enabled.
  bool get isItalic => _cell.attributes.italic;

  /// Whether any underline style is enabled.
  bool get isUnderline =>
      _cell.attributes.underline != TerminalUnderlineStyle.none;

  /// Whether blinking is enabled.
  bool get isBlink => _cell.attributes.blink;

  /// Whether foreground and background are inverted.
  bool get isInverse => _cell.attributes.inverse;

  /// Whether the cell content is hidden.
  bool get isInvisible => _cell.attributes.invisible;

  /// Whether strikethrough is enabled.
  bool get isStrikethrough => _cell.attributes.strikethrough;

  /// Whether overline is enabled.
  bool get isOverline => _cell.attributes.overline;

  /// Whether selective erase protects the cell.
  bool get isProtected => _cell.attributes.protected;

  /// Numeric OSC 8 hyperlink identity, or zero outside a hyperlink.
  int get hyperlinkId => _cell.attributes.hyperlinkId;

  /// Vertical underline variant offset in the range accepted by xterm.
  int get underlineVariantOffset => _cell.attributes.underlineVariantOffset;

  /// Internal image-storage identity, or -1 outside an image tile.
  int get imageId => _cell.attributes.imageId;

  /// Tile index within [imageId], or -1 outside an image tile.
  int get imageTileId => _cell.attributes.imageTileId;

  /// Returns an independent copy of all mutable cell attributes.
  TerminalCellAttributes copyAttributes() => _cell.attributes.copy();

  /// Whether this cell carries any xterm extended attribute data.
  bool get hasExtendedAttributes => _cell.attributes.hasExtendedAttributes;

  /// Whether all attributes have their default values.
  bool get isAttributeDefault {
    final attributes = _cell.attributes;
    return attributes.foreground.mode == TerminalColorMode.defaultColor &&
        attributes.background.mode == TerminalColorMode.defaultColor &&
        !attributes.bold &&
        !attributes.dim &&
        !attributes.italic &&
        attributes.underline == TerminalUnderlineStyle.none &&
        !attributes.blink &&
        !attributes.inverse &&
        !attributes.invisible &&
        !attributes.strikethrough &&
        !attributes.overline &&
        !attributes.protected &&
        !attributes.hasExtendedAttributes;
  }

  /// Whether this cell's attributes equal those of [other].
  bool attributesEqual(TerminalCell other) {
    final left = _cell.attributes;
    final right = other._cell.attributes;
    return left.foreground == right.foreground &&
        left.background == right.background &&
        left.bold == right.bold &&
        left.dim == right.dim &&
        left.italic == right.italic &&
        left.underline == right.underline &&
        (left.underline == TerminalUnderlineStyle.none ||
            left.underlineColor == right.underlineColor) &&
        left.blink == right.blink &&
        left.inverse == right.inverse &&
        left.invisible == right.invisible &&
        left.strikethrough == right.strikethrough &&
        left.overline == right.overline;
  }
}

/// One mutable line in a terminal buffer.
final class TerminalBufferLine {
  /// Creates an empty line containing [length] cells.
  TerminalBufferLine(
    int length, {
    this.isWrapped = false,
    TerminalCellAttributes? attributes,
    this.stringCache,
  }) : _cells = List<_CellData>.generate(
         length,
         (_) => _CellData(attributes: attributes),
       );

  TerminalBufferLine._(
    this._cells, {
    required this.isWrapped,
    this.stringCache,
  });

  final List<_CellData> _cells;

  /// Shared canonical translation cache, when this line belongs to a buffer.
  final BufferLineStringCache? stringCache;
  BufferLineStringCacheEntry? _stringCacheEntry;

  /// Whether this line continues the preceding logical line.
  bool isWrapped;

  /// Number of cells in this line.
  int get length => _cells.length;

  /// Returns the cell at [index], or `null` when out of range.
  TerminalCell? getCell(int index, [TerminalCell? destination]) {
    if (index < 0 || index >= length) return null;
    final source = _cells[index];
    if (destination == null) return TerminalCell._(source);
    destination._cell
      ..chars = source.chars
      ..width = source.width
      ..attributes = source.attributes.copy();
    return destination;
  }

  /// Converts a cell range into its textual representation.
  String translateToString({
    bool trimRight = false,
    int startColumn = 0,
    int? endColumn,
    List<int>? outputColumns,
  }) {
    final isCanonicalRequest =
        startColumn == 0 && endColumn == null && outputColumns == null;
    final cache = isCanonicalRequest ? stringCache : null;
    cache?.touch();
    final cachedEntry = cache == null ? null : _getStringCacheEntry(false);
    final cachedValue = cachedEntry?.value;
    if (cachedValue != null) {
      if (trimRight) {
        return cachedEntry!.isTrimmed ? cachedValue : cachedValue.trimRight();
      }
      if (!cachedEntry!.isTrimmed) return cachedValue;
    }
    var start = startColumn.clamp(0, length);
    var end = (endColumn ?? length).clamp(start, length);
    if (trimRight) {
      final trimmedLength = getTrimmedLength();
      if (trimmedLength < end) end = trimmedLength;
    }
    outputColumns?.clear();
    final output = StringBuffer();
    while (start < end) {
      final cell = _cells[start];
      final chars = cell.chars.isEmpty ? ' ' : cell.chars;
      output.write(chars);
      for (var index = 0; index < chars.length; index++) {
        outputColumns?.add(start);
      }
      start += cell.width == 0 ? 1 : cell.width;
    }
    outputColumns?.add(start);
    final value = output.toString();
    if (cache != null) {
      _getStringCacheEntry(true)!.setValue(value, isTrimmed: trimRight);
    }
    return value;
  }

  /// Returns an independent copy of this line.
  TerminalBufferLine copy() => TerminalBufferLine._(
    _cells.map((cell) => cell.copy()).toList(growable: false),
    isWrapped: isWrapped,
    stringCache: stringCache,
  );

  /// Replaces this line with an independent copy of [source].
  void copyFrom(TerminalBufferLine source) {
    _invalidateStringCache();
    _cells
      ..clear()
      ..addAll(source._cells.map((cell) => cell.copy()));
    isWrapped = source.isWrapped;
  }

  /// Fills every unprotected cell, or every cell when protection is ignored.
  void fill(
    TerminalCellAttributes attributes, {
    bool respectProtection = false,
    String chars = '',
    int width = 1,
  }) {
    _invalidateStringCache();
    for (final cell in _cells) {
      if (!respectProtection || !cell.attributes.protected) {
        cell
          ..chars = chars
          ..width = width
          ..attributes = attributes.copy();
      }
    }
  }

  /// Returns the buffer column immediately after the last content cell.
  int getTrimmedLength() {
    for (var index = length - 1; index >= 0; index--) {
      final cell = _cells[index];
      if (cell.chars.isNotEmpty) return index + cell.width;
    }
    return 0;
  }

  /// Returns the trimmed length, also treating non-default backgrounds as data.
  int getNoBackgroundTrimmedLength() {
    for (var index = length - 1; index >= 0; index--) {
      final cell = _cells[index];
      if (cell.chars.isNotEmpty ||
          cell.attributes.background.mode != TerminalColorMode.defaultColor) {
        return index + cell.width;
      }
    }
    return 0;
  }

  /// Resizes this line to [columns] cells.
  void resize(
    int columns,
    TerminalCellAttributes eraseAttributes, {
    String chars = '',
    int width = 1,
  }) {
    _invalidateStringCache();
    if (columns < length) {
      _cells.removeRange(columns, length);
    } else {
      _cells.addAll(
        List<_CellData>.generate(
          columns - length,
          (_) => _CellData(
            chars: chars,
            width: width,
            attributes: eraseAttributes,
          ),
        ),
      );
    }
  }

  /// Replaces a cell and writes its wide-character continuation when needed.
  void setCell(
    int index,
    String chars,
    int width,
    TerminalCellAttributes attributes,
  ) {
    if (index < 0 || index >= length) return;
    _invalidateStringCache();
    _cells[index]
      ..chars = chars
      ..width = width
      ..attributes = attributes.copy();
    if (width == 2 && index + 1 < length) {
      _cells[index + 1]
        ..chars = ''
        ..width = 0
        ..attributes = attributes.copy();
    }
  }

  /// Stores one Unicode scalar and its display width using [attributes].
  void setCellFromCodepoint(
    int index,
    int codePoint,
    int width,
    TerminalCellAttributes attributes,
  ) => setCell(index, String.fromCharCode(codePoint), width, attributes);

  /// Appends [value] to the base cell at or before [index].
  void appendCombining(int index, String value) {
    if (index < 0 || index >= length) return;
    _invalidateStringCache();
    var target = index;
    while (target > 0 && _cells[target].width == 0) {
      target--;
    }
    _cells[target].chars += value;
  }

  /// Adds [codePoint] to [index], matching xterm's combined-cell behavior.
  void addCodepointToCell(int index, int codePoint, {int width = 0}) {
    if (index < 0 || index >= length) return;
    _invalidateStringCache();
    final wasEmpty = _cells[index].chars.isEmpty;
    final cell = _cells[index]..chars += String.fromCharCode(codePoint);
    if (wasEmpty && cell.width == 0) cell.width = 1;
    if (width != 0) cell.width = width;
  }

  /// Joins [value] into the cell at [index] and updates its display [width].
  void joinCell(int index, String value, int width) {
    if (index < 0 || index >= length) return;
    _invalidateStringCache();
    final cell = _cells[index]
      ..chars += value
      ..width = width;
    if (width == 2 && index + 1 < length) {
      _cells[index + 1]
        ..chars = ''
        ..width = 0
        ..attributes = cell.attributes.copy();
    }
  }

  /// Inserts blank cells at [index], shifting existing cells right.
  void insertCells(
    int index,
    int count,
    TerminalCellAttributes eraseAttributes, {
    String chars = '',
    int width = 1,
  }) {
    if (count <= 0 || length == 0) return;
    _invalidateStringCache();
    final position = index % length;
    if (position < 0) return;
    if (position > 0 && _cells[position - 1].width == 2) {
      _cells[position - 1].reset(eraseAttributes);
    }
    final oldLength = length;
    final amount = count.clamp(0, oldLength - position);
    _cells
      ..insertAll(
        position,
        List<_CellData>.generate(
          amount,
          (_) => _CellData(
            chars: chars,
            width: width,
            attributes: eraseAttributes,
          ),
        ),
      )
      ..removeRange(oldLength, oldLength + amount);
    if (_cells.last.width == 2) _cells.last.reset(eraseAttributes);
  }

  /// Deletes cells at [index], appending blank cells at the right edge.
  void deleteCells(
    int index,
    int count,
    TerminalCellAttributes eraseAttributes, {
    String chars = '',
    int width = 1,
  }) {
    if (count <= 0 || length == 0) return;
    _invalidateStringCache();
    final position = index % length;
    if (position < 0) return;
    final amount = count.clamp(0, length - position);
    _cells
      ..removeRange(position, position + amount)
      ..addAll(
        List<_CellData>.generate(
          amount,
          (_) => _CellData(
            chars: chars,
            width: width,
            attributes: eraseAttributes,
          ),
        ),
      );
    if (position > 0 && _cells[position - 1].width == 2) {
      _cells[position - 1].reset(eraseAttributes);
    }
    if (_cells[position].width == 0 && _cells[position].chars.isEmpty) {
      _cells[position].reset(eraseAttributes);
    }
  }

  /// Erases cells in the half-open range from [start] to [end].
  void erase(
    int start,
    int end,
    TerminalCellAttributes eraseAttributes, {
    bool respectProtection = false,
  }) {
    _invalidateStringCache();
    final first = start.clamp(0, length);
    final last = end.clamp(first, length);
    if (first > 0 &&
        _cells[first - 1].width == 2 &&
        (!respectProtection || !_cells[first - 1].attributes.protected)) {
      _cells[first - 1].reset(eraseAttributes);
    }
    if (last < length &&
        last > 0 &&
        _cells[last - 1].width == 2 &&
        (!respectProtection || !_cells[last].attributes.protected)) {
      _cells[last].reset(eraseAttributes);
    }
    for (var index = first; index < last; index++) {
      if (respectProtection && _cells[index].attributes.protected) continue;
      _cells[index].reset(eraseAttributes);
    }
  }

  /// xterm-compatible name for replacing a half-open cell range.
  void replaceCells(
    int start,
    int end,
    TerminalCellAttributes eraseAttributes, {
    bool respectProtection = false,
    String chars = '',
    int width = 1,
  }) {
    if (chars.isEmpty && width == 1) {
      erase(start, end, eraseAttributes, respectProtection: respectProtection);
      return;
    }
    _invalidateStringCache();
    final first = start.clamp(0, length);
    final last = end.clamp(first, length);
    if (first > 0 &&
        _cells[first - 1].width == 2 &&
        (!respectProtection || !_cells[first - 1].attributes.protected)) {
      _cells[first - 1].reset(eraseAttributes);
    }
    if (last < length &&
        last > 0 &&
        _cells[last - 1].width == 2 &&
        (!respectProtection || !_cells[last].attributes.protected)) {
      _cells[last].reset(eraseAttributes);
    }
    for (var index = first; index < last; index++) {
      if (respectProtection && _cells[index].attributes.protected) continue;
      _cells[index]
        ..chars = chars
        ..width = width
        ..attributes = eraseAttributes.copy();
    }
  }

  /// Copies [count] cells from [source] without creating public cell objects.
  void copyCellsFrom(
    TerminalBufferLine source,
    int sourceColumn,
    int destinationColumn,
    int count, {
    bool applyInReverse = false,
  }) {
    _invalidateStringCache();
    final indices = applyInReverse
        ? Iterable<int>.generate(count, (index) => count - index - 1)
        : Iterable<int>.generate(count);
    for (final index in indices) {
      final sourceIndex = sourceColumn + index;
      final destinationIndex = destinationColumn + index;
      if (sourceIndex < 0 ||
          sourceIndex >= source.length ||
          destinationIndex < 0 ||
          destinationIndex >= length) {
        continue;
      }
      _cells[destinationIndex] = source._cells[sourceIndex].copy();
    }
  }

  /// Dart lists do not retain a separately observable spare backing store.
  int cleanupMemory() => 0;

  BufferLineStringCacheEntry? _getStringCacheEntry(bool createIfNeeded) {
    final cache = stringCache;
    if (cache == null) return null;
    final entry = _stringCacheEntry;
    if (entry != null && entry.generation == cache.generation) return entry;
    if (!createIfNeeded) return null;
    return _stringCacheEntry = cache.allocateEntry();
  }

  void _invalidateStringCache() {
    final entry = _getStringCacheEntry(false);
    if (entry == null) return;
    entry
      ..value = null
      ..isTrimmed = false;
  }
}

/// Computes xterm's exact wrap lengths when a logical line is made narrower.
///
/// The returned lengths include cell columns rather than Unicode scalar or
/// grapheme counts. A wide cell is moved as a unit when it would otherwise
/// straddle the new right edge. As in xterm.js, [newColumns] must be greater
/// than one (matching xterm, passing one does not terminate).
List<int> reflowSmallerGetNewLineLengths(
  List<TerminalBufferLine> wrappedLines,
  int oldColumns,
  int newColumns,
) {
  final newLineLengths = <int>[];
  var cellsNeeded = 0;
  for (var index = 0; index < wrappedLines.length; index++) {
    cellsNeeded += _wrappedLineTrimmedLength(wrappedLines, index, oldColumns);
  }

  var sourceColumn = 0;
  var sourceLine = 0;
  var cellsAvailable = 0;
  while (cellsAvailable < cellsNeeded) {
    if (cellsNeeded - cellsAvailable < newColumns) {
      newLineLengths.add(cellsNeeded - cellsAvailable);
      break;
    }
    sourceColumn += newColumns;
    final oldTrimmedLength = _wrappedLineTrimmedLength(
      wrappedLines,
      sourceLine,
      oldColumns,
    );
    if (sourceColumn > oldTrimmedLength) {
      sourceColumn -= oldTrimmedLength;
      sourceLine++;
    }
    final endsWithWide =
        wrappedLines[sourceLine]._cells[sourceColumn - 1].width == 2;
    if (endsWithWide) sourceColumn--;
    final lineLength = endsWithWide ? newColumns - 1 : newColumns;
    newLineLengths.add(lineLength);
    cellsAvailable += lineLength;
  }
  return newLineLengths;
}

/// Mutates wrapped blocks for xterm's grow-column reflow pass and returns
/// alternating `start, count` pairs for rows that became redundant.
List<int> reflowLargerGetLinesToRemove(
  List<TerminalBufferLine> lines,
  int oldColumns,
  int newColumns,
  int bufferAbsoluteY,
  TerminalCellAttributes nullAttributes, {
  required bool reflowCursorLine,
}) {
  final toRemove = <int>[];
  for (var y = 0; y < lines.length - 1; y++) {
    var index = y + 1;
    var nextLine = lines[index];
    if (!nextLine.isWrapped) continue;

    final wrappedLines = <TerminalBufferLine>[lines[y]];
    while (index < lines.length && nextLine.isWrapped) {
      wrappedLines.add(nextLine);
      index++;
      if (index < lines.length) nextLine = lines[index];
    }

    if (!reflowCursorLine && bufferAbsoluteY >= y && bufferAbsoluteY < index) {
      y += wrappedLines.length - 1;
      continue;
    }

    var destinationLineIndex = 0;
    var destinationColumn = _wrappedLineTrimmedLength(
      wrappedLines,
      destinationLineIndex,
      oldColumns,
    );
    var sourceLineIndex = 1;
    var sourceColumn = 0;
    while (sourceLineIndex < wrappedLines.length) {
      final sourceTrimmedLength = _wrappedLineTrimmedLength(
        wrappedLines,
        sourceLineIndex,
        oldColumns,
      );
      final sourceRemainingCells = sourceTrimmedLength - sourceColumn;
      final destinationRemainingCells = newColumns - destinationColumn;
      final cellsToCopy = sourceRemainingCells < destinationRemainingCells
          ? sourceRemainingCells
          : destinationRemainingCells;
      _copyCellsFrom(
        wrappedLines[destinationLineIndex],
        wrappedLines[sourceLineIndex],
        sourceColumn,
        destinationColumn,
        cellsToCopy,
      );

      destinationColumn += cellsToCopy;
      if (destinationColumn == newColumns) {
        destinationLineIndex++;
        destinationColumn = 0;
      }
      sourceColumn += cellsToCopy;
      if (sourceColumn == sourceTrimmedLength) {
        sourceLineIndex++;
        sourceColumn = 0;
      }

      if (destinationColumn == 0 && destinationLineIndex != 0) {
        final previous = wrappedLines[destinationLineIndex - 1];
        if (_cellWidth(previous, newColumns - 1) == 2) {
          _copyCellsFrom(
            wrappedLines[destinationLineIndex],
            previous,
            newColumns - 1,
            destinationColumn,
            1,
          );
          destinationColumn++;
          if (newColumns - 1 < previous.length) {
            previous._cells[newColumns - 1].reset(nullAttributes);
            previous._invalidateStringCache();
          }
        }
      }
    }

    final destinationLine = wrappedLines[destinationLineIndex];
    final destinationCells = destinationLine._cells;
    destinationLine._invalidateStringCache();
    for (var column = destinationColumn; column < newColumns; column++) {
      if (column < destinationCells.length) {
        destinationCells[column].reset(nullAttributes);
      }
    }

    var countToRemove = 0;
    for (
      var wrappedIndex = wrappedLines.length - 1;
      wrappedIndex > 0;
      wrappedIndex--
    ) {
      if (wrappedIndex > destinationLineIndex ||
          _terminalBufferLineTrimmedLength(wrappedLines[wrappedIndex]) == 0) {
        countToRemove++;
      } else {
        break;
      }
    }
    if (countToRemove > 0) {
      toRemove
        ..add(y + wrappedLines.length - countToRemove)
        ..add(countToRemove);
    }
    y += wrappedLines.length - 1;
  }
  return toRemove;
}

int _wrappedLineTrimmedLength(
  List<TerminalBufferLine> lines,
  int index,
  int columns,
) {
  if (index == lines.length - 1) {
    return _terminalBufferLineTrimmedLength(lines[index]);
  }
  final endsInNull =
      lines[index]._cells[columns - 1].chars.isEmpty &&
      lines[index]._cells[columns - 1].width == 1;
  final followingLineStartsWithWide = lines[index + 1]._cells[0].width == 2;
  return endsInNull && followingLineStartsWithWide ? columns - 1 : columns;
}

int _terminalBufferLineTrimmedLength(TerminalBufferLine line) {
  var result = line.length;
  while (result > 0) {
    final cell = line._cells[result - 1];
    if (cell.width == 0 || cell.chars.isNotEmpty) break;
    result--;
  }
  return result;
}

void _copyCellsFrom(
  TerminalBufferLine destination,
  TerminalBufferLine source,
  int sourceColumn,
  int destinationColumn,
  int length,
) {
  destination._invalidateStringCache();
  for (var offset = 0; offset < length; offset++) {
    final target = destinationColumn + offset;
    final origin = sourceColumn + offset;
    if (target < destination.length && origin < source.length) {
      destination._cells[target] = source._cells[origin].copy();
    }
  }
}

int _cellWidth(TerminalBufferLine line, int column) =>
    column < 0 || column >= line.length ? 0 : line._cells[column].width;

/// A complete normal or alternate terminal buffer.
final class TerminalBuffer implements Disposable {
  TerminalBuffer._({
    required this.type,
    required int columns,
    required int rows,
    required int scrollback,
    bool fillViewport = true,
    void Function(int amount)? onTrim,
    void Function(int index, int amount)? onInsert,
    void Function(int index, int amount)? onDelete,
  }) : _columns = columns,
       _rows = rows,
       _scrollback = _initialScrollback(scrollback),
       _onTrim = _initialCallback(onTrim),
       _onInsert = _initialCallback(onInsert),
       _onDelete = _initialCallback(onDelete) {
    if (fillViewport) {
      _lines.addAll(
        List<TerminalBufferLine>.generate(
          rows,
          (_) => _blankLine(columns, null),
        ),
      );
    }
  }

  /// Kind of this buffer.
  final TerminalBufferType type;

  /// Maximum number of retained scrollback lines.
  int get scrollback => _scrollback;
  int _scrollback;

  /// Maximum line capacity, equivalent to xterm's circular-list max length.
  int get maximumLength => _rows + _scrollback;

  /// Inclusive bottom row of the scrolling viewport.
  int get scrollBottom => _rows - 1;
  final List<TerminalBufferLine> _lines = <TerminalBufferLine>[];
  final BufferLineStringCache _stringCache = BufferLineStringCache();
  int _columns;
  int _rows;
  final void Function(int amount)? _onTrim;
  final void Function(int index, int amount)? _onInsert;
  final void Function(int index, int amount)? _onDelete;
  final List<TerminalMarker> _markers = <TerminalMarker>[];
  final TerminalMarkerFactory _markerFactory = TerminalMarkerFactory();
  final TerminalEventEmitter<int> _onTrimEmitter = TerminalEventEmitter<int>();
  final TerminalEventEmitter<TerminalBufferLineChange> _onInsertEmitter =
      TerminalEventEmitter<TerminalBufferLineChange>();
  final TerminalEventEmitter<TerminalBufferLineChange> _onDeleteEmitter =
      TerminalEventEmitter<TerminalBufferLineChange>();
  bool _isDisposed = false;

  /// Fires after lines are trimmed from the start of the buffer.
  TerminalEvent<int> get onTrim => _onTrimEmitter.event;

  /// Fires after logical lines are inserted.
  TerminalEvent<TerminalBufferLineChange> get onInsert =>
      _onInsertEmitter.event;

  /// Fires after logical lines are deleted.
  TerminalEvent<TerminalBufferLineChange> get onDelete =>
      _onDeleteEmitter.event;

  /// Markers currently anchored in this buffer.
  List<TerminalMarker> get markers =>
      List<TerminalMarker>.unmodifiable(_markers);

  /// Adds a marker at an absolute buffer line.
  TerminalMarker addMarker(int line) {
    if (_isDisposed) throw StateError('Buffer has been disposed');
    final marker = _markerFactory.create(line);
    _markers.add(marker);
    marker.onDispose.listen((_) => _markers.remove(marker));
    return marker;
  }

  /// Disposes every marker owned by this buffer.
  void clearAllMarkers() {
    for (final marker in List<TerminalMarker>.of(_markers)) {
      marker.dispose();
    }
  }

  @override
  bool get isDisposed => _isDisposed;

  /// Zero-based cursor column.
  int cursorX = 0;

  /// Cursor row relative to the viewport.
  int cursorY = 0;

  /// Saved cursor column.
  int savedCursorX = 0;

  /// Saved cursor row.
  int savedCursorY = 0;

  /// Absolute saved row used to preserve DECSC across viewport resize.
  int savedCursorAbsoluteY = 0;

  /// Attributes restored together with the saved cursor.
  TerminalCellAttributes savedAttributes = TerminalCellAttributes();

  /// ISO-2022 character sets restored with DECRC.
  List<String> savedCharsets = <String>['B', 'B', 'B', 'B'];

  /// Active saved ISO-2022 character-set level.
  int savedCharsetLevel = 0;

  /// Absolute row currently displayed at the top of the viewport.
  int get viewportY => displayY;

  /// Mutable display offset managed by the owning terminal or buffer service.
  int displayY = 0;

  /// Number of retained rows before the live viewport.
  int get baseY => type == TerminalBufferType.alternate
      ? 0
      : (_lines.length - _rows).clamp(0, _lines.length);

  /// Number of retained lines.
  int get length => _lines.length;

  /// Absolute row containing the cursor.
  int get absoluteCursorY => baseY + cursorY;

  /// Number of columns in each line.
  int get columns => _columns;

  /// Number of rows in the viewport.
  int get rows => _rows;

  /// Returns the absolute buffer line at [index].
  TerminalBufferLine? getLine(int index) =>
      index < 0 || index >= length ? null : _lines[index];

  /// Returns the first and last row of the wrapped logical line containing
  /// [lineIndex].
  ({int first, int last}) getWrappedRangeForLine(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= length) {
      throw RangeError.range(lineIndex, 0, length - 1, 'lineIndex');
    }
    var first = lineIndex;
    while (first > 0 && _lines[first].isWrapped) {
      first--;
    }
    var last = lineIndex;
    while (last + 1 < length && _lines[last + 1].isWrapped) {
      last++;
    }
    return (first: first, last: last);
  }

  /// Line containing the cursor.
  TerminalBufferLine get currentLine => _lines[absoluteCursorY];

  /// Returns an empty cell with default attributes.
  TerminalCell getNullCell() => TerminalCell._(_CellData());

  /// Translates one absolute buffer line, returning an empty string if absent.
  String translateBufferLineToString(
    int lineIndex, {
    bool trimRight = false,
    int startColumn = 0,
    int? endColumn,
  }) =>
      getLine(lineIndex)?.translateToString(
        trimRight: trimRight,
        startColumn: startColumn,
        endColumn: endColumn,
      ) ??
      '';

  /// Shared canonical line-string cache owned by this buffer.
  BufferLineStringCache get stringCache => _stringCache;

  /// Resizes the viewport and all retained lines.
  void resize(
    int columns,
    int rows,
    TerminalCellAttributes eraseAttributes, {
    bool reflowCursorLine = false,
    TerminalWindowsPtyOptions windowsPty = const TerminalWindowsPtyOptions(),
  }) {
    _stringCache.clear();
    if (type == TerminalBufferType.alternate && _lines.isEmpty) {
      _columns = columns;
      _rows = rows;
      cursorX = cursorX.clamp(0, columns - 1);
      cursorY = cursorY.clamp(0, rows - 1);
      return;
    }
    final hasWindowsPtyConfiguration =
        windowsPty.backend != null || windowsPty.buildNumber != null;
    final reflowEnabled =
        !hasWindowsPtyConfiguration ||
        windowsPty.backend == 'conpty' &&
            (windowsPty.buildNumber ?? 0) >= 21376;
    final wasViewportAtBottom = displayY == baseY;
    if (type == TerminalBufferType.normal &&
        columns != _columns &&
        reflowEnabled) {
      _reflow(columns, eraseAttributes, reflowCursorLine);
    }
    final oldRows = _rows;
    final oldBase = baseY;
    final absoluteCursor = oldBase + cursorY;
    for (final line in _lines) {
      line.resize(columns, eraseAttributes);
    }
    if (rows > oldRows) {
      final growth = rows - oldRows;
      final canRevealHistory =
          !hasWindowsPtyConfiguration &&
          oldBase > 0 &&
          _lines.length <= absoluteCursor + 1;
      final linesToAdd = hasWindowsPtyConfiguration
          ? growth
          : canRevealHistory
          ? growth > oldBase
                ? growth - oldBase
                : 0
          : growth;
      _lines.addAll(
        List<TerminalBufferLine>.generate(
          linesToAdd,
          (_) => _blankLine(columns, eraseAttributes),
        ),
      );
    } else if (rows < oldRows) {
      final minimumLength = rows + oldBase;
      while (_lines.length > minimumLength &&
          _lines.length > absoluteCursor + 1) {
        _deleteLines(_lines.length - 1, 1);
        _lines.removeLast();
      }
    }
    _columns = columns;
    _rows = rows;
    while (_lines.length < rows) {
      _lines.add(_blankLine(columns, eraseAttributes));
    }
    _trim();
    cursorX = cursorX.clamp(0, columns - 1);
    cursorY = (absoluteCursor - baseY).clamp(0, rows - 1);
    savedCursorY = savedCursorY.clamp(0, rows - 1);
    displayY = wasViewportAtBottom ? baseY : displayY.clamp(0, baseY);
  }

  /// Replaces all content with an empty viewport.
  void clear([TerminalCellAttributes? eraseAttributes]) {
    _stringCache.clear();
    _deleteLines(0, _lines.length);
    _lines
      ..clear()
      ..addAll(
        List<TerminalBufferLine>.generate(
          _rows,
          (_) => _blankLine(_columns, eraseAttributes),
        ),
      );
    cursorX = 0;
    cursorY = 0;
    displayY = 0;
  }

  /// Clears all alternate-buffer storage while it is inactive.
  void clearToEmpty() {
    _stringCache.clear();
    _deleteLines(0, _lines.length);
    _lines.clear();
    cursorX = 0;
    cursorY = 0;
    displayY = 0;
  }

  /// Discards history while retaining the cursor line as the first line.
  ///
  /// This is the buffer mutation used by xterm's public `Terminal.clear` API.
  /// The retained line is not serialized and written again, so its cells,
  /// attributes, wrapping state and the cursor column stay intact.
  void clearKeepingCursorLine([TerminalCellAttributes? eraseAttributes]) {
    final promptLine = currentLine;
    _deleteLines(0, _lines.length);
    _lines
      ..clear()
      ..add(promptLine)
      ..addAll(
        List<TerminalBufferLine>.generate(
          _rows - 1,
          (_) => _blankLine(_columns, eraseAttributes),
        ),
      );
    cursorY = 0;
    displayY = 0;
  }

  /// Removes retained scrollback without changing the visible viewport.
  void clearScrollback() {
    final retained = baseY;
    if (retained > 0) {
      _lines.removeRange(0, retained);
      _trimLines(retained);
      displayY = 0;
    }
  }

  /// Updates the retained history limit and immediately removes excess lines.
  void updateScrollback(int value) {
    if (type == TerminalBufferType.alternate || _scrollback == value) return;
    _scrollback = value;
    _trim();
  }

  /// Scrolls the inclusive region from [top] through [bottom] upward.
  void scroll(
    TerminalCellAttributes eraseAttributes, {
    int top = 0,
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    if (top == 0 && last == _rows - 1 && type == TerminalBufferType.normal) {
      _lines.add(_blankLine(_columns, eraseAttributes));
      _trim();
      return;
    }
    final start = baseY + top;
    final end = baseY + last;
    _deleteLines(start, 1);
    _insertLines(end, 1);
    _lines
      ..removeAt(start)
      ..insert(end, _blankLine(_columns, eraseAttributes));
  }

  /// Scrolls the inclusive region from [top] through [bottom] downward.
  void reverseScroll(
    TerminalCellAttributes eraseAttributes, {
    int top = 0,
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    final start = baseY + top;
    final end = baseY + last;
    _deleteLines(end, 1);
    _insertLines(start, 1);
    _lines
      ..removeAt(end)
      ..insert(start, _blankLine(_columns, eraseAttributes));
  }

  /// Inserts [count] blank lines at viewport-relative [row].
  void insertLines(
    int row,
    int count,
    TerminalCellAttributes eraseAttributes, {
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    final amount = count.clamp(0, last - row + 1);
    final start = baseY + row;
    final end = baseY + last + 1;
    _insertLines(start, amount);
    _deleteLines(end, amount, reverseDisposal: true);
    _lines
      ..insertAll(
        start,
        List<TerminalBufferLine>.generate(
          amount,
          (_) => _blankLine(_columns, eraseAttributes),
        ),
      )
      ..removeRange(end, end + amount);
  }

  /// Deletes [count] lines at viewport-relative [row].
  void deleteLines(
    int row,
    int count,
    TerminalCellAttributes eraseAttributes, {
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    final amount = count.clamp(0, last - row + 1);
    final start = baseY + row;
    final insertion = baseY + last - amount + 1;
    _deleteLines(start, amount);
    _insertLines(insertion, amount);
    _lines
      ..removeRange(start, start + amount)
      ..insertAll(
        insertion,
        List<TerminalBufferLine>.generate(
          amount,
          (_) => _blankLine(_columns, eraseAttributes),
        ),
      );
  }

  void _reflow(
    int newColumns,
    TerminalCellAttributes eraseAttributes,
    bool reflowCursorLine,
  ) {
    final oldColumns = _columns;
    final oldLength = _lines.length;
    final oldBaseY = baseY;
    final oldCursorY = cursorY;
    var cursorAbsolute = absoluteCursorY;
    var groupStart = 0;
    while (groupStart < _lines.length) {
      var groupEnd = groupStart;
      while (groupEnd + 1 < _lines.length && _lines[groupEnd + 1].isWrapped) {
        groupEnd++;
      }
      final containsCursor =
          cursorAbsolute >= groupStart && cursorAbsolute <= groupEnd;
      final lastLength = _trimmedLength(_lines[groupEnd]);
      final needsReflow =
          groupEnd > groupStart ||
          (newColumns < oldColumns && lastLength > newColumns);
      if (!needsReflow || containsCursor && !reflowCursorLine) {
        groupStart = groupEnd + 1;
        continue;
      }

      final firstWasWrapped = _lines[groupStart].isWrapped;
      final cells = <_CellData>[];
      var cursorOffset = 0;
      for (var row = groupStart; row <= groupEnd; row++) {
        final line = _lines[row];
        var used = row == groupEnd ? lastLength : oldColumns;
        if (row < groupEnd &&
            used > 0 &&
            line._cells[used - 1].chars.isEmpty &&
            line._cells[used - 1].width == 1 &&
            _lines[row + 1]._cells.first.width == 2) {
          used--;
        }
        if (containsCursor && row < cursorAbsolute) cursorOffset += used;
        if (containsCursor && row == cursorAbsolute) {
          cursorOffset += cursorX.clamp(0, used);
        }
        for (var column = 0; column < used; column++) {
          final cell = line._cells[column];
          if (cell.width == 0) continue;
          cells.add(
            _CellData(
              chars: cell.chars,
              width: cell.width,
              attributes: cell.attributes,
            ),
          );
        }
      }

      final layout = _layoutReflowedCells(
        cells,
        newColumns,
        eraseAttributes,
        firstWasWrapped,
        containsCursor ? cursorOffset : null,
      );
      final oldCount = groupEnd - groupStart + 1;
      _lines.replaceRange(groupStart, groupEnd + 1, layout.lines);
      final delta = layout.lines.length - oldCount;
      if (delta > 0) {
        _insertLines(groupEnd + 1, delta);
      } else if (delta < 0) {
        _deleteLines(groupStart + layout.lines.length, -delta);
      }
      if (containsCursor) {
        cursorAbsolute = groupStart + layout.cursorRow;
        cursorX = layout.cursorColumn;
      } else if (groupEnd < cursorAbsolute) {
        cursorAbsolute += delta;
      }
      groupStart += layout.lines.length;
    }
    if (newColumns < oldColumns && oldBaseY == 0) {
      // xterm consumes unused viewport rows from the bottom before newly
      // reflowed rows are allowed to create scrollback. CircularList.pop does
      // not emit a deletion event, so markers shifted by the insertions above
      // remain attached to their reflowed logical lines.
      final addedLines = (_lines.length - oldLength).clamp(0, _lines.length);
      final unusedViewportRows = (_rows - oldCursorY - 1).clamp(0, _rows);
      final rowsToPop = addedLines < unusedViewportRows
          ? addedLines
          : unusedViewportRows;
      if (rowsToPop > 0) {
        _lines.removeRange(_lines.length - rowsToPop, _lines.length);
      }
    }
    cursorY = (cursorAbsolute - baseY).clamp(0, _rows - 1);
  }

  _ReflowLayout _layoutReflowedCells(
    List<_CellData> cells,
    int columns,
    TerminalCellAttributes eraseAttributes,
    bool firstWasWrapped,
    int? cursorOffset,
  ) {
    final lines = <TerminalBufferLine>[
      _blankLine(columns, eraseAttributes, isWrapped: firstWasWrapped),
    ];
    var row = 0;
    var column = 0;
    var consumed = 0;
    var cursorRow = 0;
    var cursorColumn = 0;
    var cursorCaptured = cursorOffset == null;

    void captureCursor() {
      if (cursorCaptured || consumed < cursorOffset!) return;
      cursorRow = row;
      cursorColumn = column;
      cursorCaptured = true;
    }

    for (final cell in cells) {
      captureCursor();
      final width = cell.width == 2 ? 2 : 1;
      if (column + width > columns) {
        lines.add(_blankLine(columns, eraseAttributes, isWrapped: true));
        row++;
        column = 0;
        captureCursor();
      }
      lines[row].setCell(column, cell.chars, width, cell.attributes);
      column += width;
      consumed += width;
    }
    captureCursor();
    if (!cursorCaptured) {
      cursorRow = row;
      cursorColumn = column;
    }
    return _ReflowLayout(lines, cursorRow, cursorColumn);
  }

  int _trimmedLength(TerminalBufferLine line) {
    var result = line.length;
    while (result > 0) {
      final cell = line._cells[result - 1];
      if (cell.width == 0 || cell.chars.isNotEmpty) break;
      result--;
    }
    return result;
  }

  TerminalBufferLine _blankLine(
    int columns,
    TerminalCellAttributes? attributes, {
    bool isWrapped = false,
  }) => TerminalBufferLine(
    columns,
    attributes: attributes,
    isWrapped: isWrapped,
    stringCache: _stringCache,
  );

  void _trim() {
    final maximum =
        _rows + (type == TerminalBufferType.normal ? scrollback : 0);
    if (_lines.length > maximum) {
      final amount = _lines.length - maximum;
      _lines.removeRange(0, amount);
      _trimLines(amount);
    }
  }

  void _trimLines(int amount) {
    for (final marker in List<TerminalMarker>.of(_markers)) {
      marker.move(-amount);
    }
    _onTrim?.call(amount);
    _onTrimEmitter.fire(amount);
  }

  void _insertLines(int index, int amount) {
    for (final marker in _markers) {
      if (marker.line >= index) marker.move(amount);
    }
    _onInsert?.call(index, amount);
    _onInsertEmitter.fire(
      TerminalBufferLineChange(index: index, amount: amount),
    );
  }

  void _deleteLines(int index, int amount, {bool reverseDisposal = false}) {
    final end = index + amount;
    final markers = List<TerminalMarker>.of(_markers);
    if (reverseDisposal) {
      markers.sort((left, right) => right.line.compareTo(left.line));
    }
    for (final marker in markers) {
      if (marker.line >= index && marker.line < end) {
        marker.dispose();
      } else if (marker.line >= end) {
        marker.move(-amount);
      }
    }
    _onDelete?.call(index, amount);
    _onDeleteEmitter.fire(
      TerminalBufferLineChange(index: index, amount: amount),
    );
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    clearAllMarkers();
    _stringCache.dispose();
    _onTrimEmitter.dispose();
    _onInsertEmitter.dispose();
    _onDeleteEmitter.dispose();
    _lines.clear();
  }

  static int _initialScrollback(int value) => value;
  static T _initialCallback<T>(T value) => value;
}

final class _ReflowLayout {
  const _ReflowLayout(this.lines, this.cursorRow, this.cursorColumn);

  final List<TerminalBufferLine> lines;
  final int cursorRow;
  final int cursorColumn;
}

/// Normal, alternate, and active buffers.
final class TerminalBufferActivation {
  /// Creates a buffer activation event.
  const TerminalBufferActivation({
    required this.activeBuffer,
    required this.inactiveBuffer,
  });

  /// Buffer that became active.
  final TerminalBuffer activeBuffer;

  /// Buffer that became inactive.
  final TerminalBuffer inactiveBuffer;
}

/// Normal, alternate, and active buffers.
final class TerminalBufferNamespace implements Disposable {
  /// Creates normal and alternate buffers with the given dimensions.
  TerminalBufferNamespace({
    required int columns,
    required int rows,
    required int scrollback,
    void Function(int amount)? onTrim,
    void Function(int index, int amount)? onInsert,
    void Function(int index, int amount)? onDelete,
  }) : this._(columns, rows, scrollback, onTrim, onInsert, onDelete);

  TerminalBufferNamespace._(
    this._columns,
    this._rows,
    this._scrollback,
    this._onTrim,
    this._onInsert,
    this._onDelete,
  ) {
    reset();
  }

  /// Normal buffer with scrollback history.
  TerminalBuffer get normal => _normal;
  late TerminalBuffer _normal;

  /// Alternate screen buffer.
  TerminalBuffer get alternate => _alternate;
  late TerminalBuffer _alternate;
  late TerminalBuffer _active;
  int _columns;
  int _rows;
  final int _scrollback;
  final void Function(int amount)? _onTrim;
  final void Function(int index, int amount)? _onInsert;
  final void Function(int index, int amount)? _onDelete;
  bool _initialized = false;
  bool _isDisposed = false;
  final TerminalEventEmitter<TerminalBuffer> _onBufferChange =
      TerminalEventEmitter<TerminalBuffer>();
  final TerminalEventEmitter<TerminalBufferActivation> _onBufferActivate =
      TerminalEventEmitter<TerminalBufferActivation>();

  /// Buffer currently receiving input and being rendered.
  TerminalBuffer get active => _active;

  /// Fires synchronously after the active buffer changes.
  TerminalEvent<TerminalBuffer> get onBufferChange => _onBufferChange.event;

  /// Fires synchronously with both sides of an xterm buffer activation.
  TerminalEvent<TerminalBufferActivation> get onBufferActivate =>
      _onBufferActivate.event;

  /// Replaces both buffers and activates a fresh normal buffer.
  void reset() {
    if (_isDisposed) throw StateError('Buffer set has been disposed');
    if (_initialized) {
      _normal.dispose();
      _alternate.dispose();
    }
    _normal = TerminalBuffer._(
      type: TerminalBufferType.normal,
      columns: _columns,
      rows: _rows,
      scrollback: _scrollback,
      onTrim: _onTrim,
      onInsert: _onInsert,
      onDelete: _onDelete,
    );
    _alternate = TerminalBuffer._(
      type: TerminalBufferType.alternate,
      columns: _columns,
      rows: _rows,
      scrollback: 0,
      fillViewport: false,
    );
    _active = _normal;
    _initialized = true;
    _fireActivation(_normal, _alternate);
  }

  /// Activates the normal buffer.
  void useNormal() {
    if (identical(_active, normal)) return;
    normal
      ..cursorX = alternate.cursorX
      ..cursorY = alternate.cursorY;
    alternate
      ..clearAllMarkers()
      ..clearToEmpty();
    _switch(normal);
  }

  /// Activates the alternate buffer, optionally clearing it first.
  void useAlternate([TerminalCellAttributes? eraseAttributes]) {
    if (identical(_active, alternate)) return;
    // xterm keeps the inactive alternate buffer storage-free, then fills a
    // fresh viewport before the input handler can address its cursor line.
    alternate
      ..clear(eraseAttributes)
      ..cursorX = normal.cursorX
      ..cursorY = normal.cursorY;
    _switch(alternate);
  }

  void _switch(TerminalBuffer value) {
    if (identical(_active, value)) return;
    final inactive = _active;
    _active = value;
    _fireActivation(value, inactive);
  }

  void _fireActivation(TerminalBuffer active, TerminalBuffer inactive) {
    _onBufferChange.fire(active);
    _onBufferActivate.fire(
      TerminalBufferActivation(activeBuffer: active, inactiveBuffer: inactive),
    );
  }

  /// Resizes both buffers.
  void resize(
    int columns,
    int rows,
    TerminalCellAttributes eraseAttributes, {
    bool reflowCursorLine = false,
    TerminalWindowsPtyOptions windowsPty = const TerminalWindowsPtyOptions(),
  }) {
    _columns = columns;
    _rows = rows;
    normal.resize(
      columns,
      rows,
      eraseAttributes,
      reflowCursorLine: reflowCursorLine,
      windowsPty: windowsPty,
    );
    alternate.resize(columns, rows, eraseAttributes, windowsPty: windowsPty);
  }

  @override
  bool get isDisposed => _isDisposed;

  /// Releases both buffers and buffer-change listeners.
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    normal.dispose();
    alternate.dispose();
    _onBufferChange.dispose();
    _onBufferActivate.dispose();
  }
}
