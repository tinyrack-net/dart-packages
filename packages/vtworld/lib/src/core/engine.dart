part of 'terminal.dart';

/// Mouse tracking protocol selected by DECSET.
enum TerminalMouseTrackingMode {
  /// Mouse reporting is disabled.
  none,

  /// Report only button presses using the legacy X10 protocol.
  x10,

  /// Report button presses and releases.
  vt200,

  /// Report button events and motion while a button is held.
  drag,

  /// Report all pointer motion and button events.
  any,
}

/// Standalone VT input handler ported from xterm.js' common input pipeline.
final class _TerminalCoreEngine {
  _TerminalCoreEngine({
    required this.options,
    required this.unicode,
    required int columns,
    required int rows,
    required int scrollback,
    this.onBell,
    this.onData,
    this.onTitle,
    this.onRequestSendFocus,
    this.onA11yChar,
    this.onA11yTab,
    this.onLineFeed,
    this.onTrim,
  }) : buffer = TerminalBufferNamespace(
         columns: columns,
         rows: rows,
         scrollback: scrollback,
         onTrim: onTrim,
       ),
       _columns = columns,
       _rows = rows {
    _resetTabStops();
  }

  final TerminalBufferNamespace buffer;
  final TerminalOptions options;
  final TerminalUnicodeHandling unicode;
  void Function()? onBell;
  void Function(String data)? onData;
  void Function(String title)? onTitle;
  void Function()? onRequestSendFocus;
  void Function(String character)? onA11yChar;
  void Function(int spaceCount)? onA11yTab;
  void Function()? onLineFeed;
  void Function(int amount)? onTrim;
  int _columns;
  int _rows;
  int marginTop = 0;
  late int marginBottom = _rows - 1;
  bool insertMode = false;
  bool originMode = false;
  bool autoWrapMode = true;
  bool cursorVisibleMode = true;
  bool cursorKeysMode = false;
  bool appKeypadMode = false;
  bool reportFocusMode = false;
  bool bracketedPasteMode = false;
  bool colorSchemeUpdates = false;
  bool reverseWraparoundMode = false;
  bool synchronizedOutputMode = false;
  bool win32InputMode = false;
  bool lineFeedMode = false;
  bool applicationEscapeMode = false;
  TerminalMouseTrackingMode mouseMode = TerminalMouseTrackingMode.none;
  bool sgrMouseMode = false;
  bool sgrPixelsMouseMode = false;
  bool utf8MouseMode = false;
  bool urxvtMouseMode = false;
  bool alternateScrollMode = false;
  bool sendCursorPosition = false;
  TerminalCursorStyle? cursorStyleOverride;
  bool? cursorBlinkOverride;
  TerminalRenderDimensions? renderDimensions;
  int kittyKeyboardFlags = 0;
  int _kittyMainFlags = 0;
  int _kittyAlternateFlags = 0;
  final List<int> _kittyMainStack = <int>[];
  final List<int> _kittyAlternateStack = <int>[];
  bool _pendingWrap = false;
  int _savedMarginTop = 0;
  int _savedMarginBottom = 0;
  bool _savedOriginMode = false;
  bool _savedAutoWrapMode = true;
  final Set<int> _tabStops = <int>{};
  String _windowTitle = '';
  String _iconName = '';
  final List<String> _windowTitleStack = <String>[];
  final List<String> _iconNameStack = <String>[];
  TerminalCellAttributes _attributes = TerminalCellAttributes();
  TerminalCellAttributes _eraseAttributes = TerminalCellAttributes();
  String _charset = 'B';
  String _g0 = 'B';
  String _g1 = 'B';
  String _g2 = 'B';
  String _g3 = 'B';
  int _activeCharset = 0;
  String _precedingCharacter = '';
  int _precedingJoinState = 0;
  int _nextHyperlinkId = 1;
  final Map<int, ({String? id, String uri})> _hyperlinks =
      <int, ({String? id, String uri})>{};
  final Map<String, int> _hyperlinksByExplicitId = <String, int>{};
  final Map<int, int> _indexedColorOverrides = <int, int>{};
  int? _foregroundColorOverride;
  int? _backgroundColorOverride;
  int? _cursorColorOverride;

  int get columns => _columns;
  int get rows => _rows;
  TerminalCellAttributes get currentAttributes => _attributes.copy();
  TerminalColorOverrides get colorOverrides => TerminalColorOverrides(
    indexed: _indexedColorOverrides,
    foreground: _foregroundColorOverride,
    background: _backgroundColorOverride,
    cursor: _cursorColorOverride,
  );

  void write(String input) {
    var index = 0;
    while (index < input.length) {
      final code = input.codeUnitAt(index);
      if (code == 0x1b) {
        _precedingJoinState = 0;
        index = _escape(input, index);
        continue;
      }
      if (code == 0x9b) {
        _precedingJoinState = 0;
        index = _csi(input, index + 1);
        continue;
      }
      if (code < 0x20 || code == 0x7f || (code >= 0x80 && code <= 0x9f)) {
        _precedingJoinState = 0;
        _precedingCharacter = '';
        _control(code);
        index++;
        continue;
      }
      final rune = _runeAt(input, index);
      _print(String.fromCharCode(rune.value), rune.value);
      index += rune.length;
    }
  }

  ({int value, int length}) _runeAt(String source, int index) {
    final first = source.codeUnitAt(index);
    if (first >= 0xd800 && first <= 0xdbff && index + 1 < source.length) {
      final second = source.codeUnitAt(index + 1);
      if (second >= 0xdc00 && second <= 0xdfff) {
        return (
          value: 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00,
          length: 2,
        );
      }
    }
    return (value: first, length: 1);
  }

  int _escape(String source, int start) {
    if (start + 1 >= source.length) return source.length;
    final next = source.codeUnitAt(start + 1);
    if (next == 0x5b) return _csi(source, start + 2);
    _precedingCharacter = '';
    if (next == 0x5d) return _osc(source, start + 2);
    if (next == 0x50) return _dcs(source, start + 2);
    if (next == 0x5f || next == 0x5e) {
      return _consumeString(source, start + 2);
    }
    var cursor = start + 1;
    final intermediates = StringBuffer();
    while (cursor < source.length) {
      final code = source.codeUnitAt(cursor);
      if (code >= 0x20 && code <= 0x2f) {
        intermediates.writeCharCode(code);
        cursor++;
        continue;
      }
      final intermediate = intermediates.toString();
      final finalByte = String.fromCharCode(code);
      if ((intermediate == '(' ||
              intermediate == ')' ||
              intermediate == '*' ||
              intermediate == '+' ||
              intermediate == '-' ||
              intermediate == '.' ||
              intermediate == '/') &&
          code >= 0x30 &&
          code <= 0x7e) {
        _designateCharset(intermediate, finalByte);
      } else {
        _escDispatch(intermediate, finalByte);
      }
      return cursor + 1;
    }
    return source.length;
  }

  int _csi(String source, int start) {
    var cursor = start;
    while (cursor < source.length) {
      final code = source.codeUnitAt(cursor);
      if (code >= 0x40 && code <= 0x7e) break;
      cursor++;
    }
    if (cursor >= source.length) return source.length;
    final body = source.substring(start, cursor);
    var prefix = '';
    var offset = 0;
    if (body.isNotEmpty &&
        body.codeUnitAt(0) >= 0x3c &&
        body.codeUnitAt(0) <= 0x3f) {
      prefix = body[0];
      offset = 1;
    }
    final parameters = StringBuffer();
    final intermediates = StringBuffer();
    for (var index = offset; index < body.length; index++) {
      final code = body.codeUnitAt(index);
      if (code >= 0x30 && code <= 0x3b) {
        parameters.writeCharCode(code);
      } else if (code >= 0x20 && code <= 0x2f) {
        intermediates.writeCharCode(code);
      }
    }
    final params = _params(parameters.toString());
    _csiDispatch(prefix, intermediates.toString(), source[cursor], params);
    return cursor + 1;
  }

  int _osc(String source, int start) {
    var cursor = start;
    while (cursor < source.length) {
      final code = source.codeUnitAt(cursor);
      if (code == 0x07) break;
      if (code == 0x1b &&
          cursor + 1 < source.length &&
          source.codeUnitAt(cursor + 1) == 0x5c) {
        break;
      }
      cursor++;
    }
    final body = source.substring(start, cursor);
    final separator = body.indexOf(';');
    final command = int.tryParse(
      separator < 0 ? body : body.substring(0, separator),
    );
    final data = separator < 0 ? '' : body.substring(separator + 1);
    switch (command) {
      case 0:
        _windowTitle = data;
        _iconName = data;
        onTitle?.call(data);
      case 1:
        _iconName = data;
      case 2:
        _windowTitle = data;
        onTitle?.call(data);
      case 4:
        _setOrReportIndexedColor(data);
      case 8:
        _setHyperlink(data);
      case 10:
        _setOrReportSpecialColor(data, 0);
      case 11:
        _setOrReportSpecialColor(data, 1);
      case 12:
        _setOrReportSpecialColor(data, 2);
      case 104:
        _restoreIndexedColor(data);
      case 110:
        _foregroundColorOverride = null;
      case 111:
        _backgroundColorOverride = null;
      case 112:
        _cursorColorOverride = null;
    }
    if (cursor < source.length && source.codeUnitAt(cursor) == 0x1b) {
      return math.min(source.length, cursor + 2);
    }
    return math.min(source.length, cursor + 1);
  }

  void _setOrReportIndexedColor(String data) {
    final slots = data.split(';');
    for (var index = 0; index + 1 < slots.length; index += 2) {
      final colorIndex = int.tryParse(slots[index]);
      if (colorIndex == null || colorIndex < 0 || colorIndex > 255) continue;
      final specification = slots[index + 1];
      if (specification == '?') {
        _reportColor('4;$colorIndex', _effectiveIndexedColor(colorIndex));
        continue;
      }
      final color = _parseXColor(specification);
      if (color != null) _indexedColorOverrides[colorIndex] = color;
    }
  }

  void _setOrReportSpecialColor(String data, int offset) {
    final slots = data.split(';');
    var specialIndex = offset;
    for (
      var index = 0;
      index < slots.length && specialIndex < 3;
      index++, specialIndex++
    ) {
      if (slots[index] == '?') {
        _reportColor(
          '${10 + specialIndex}',
          _effectiveSpecialColor(specialIndex),
        );
        continue;
      }
      final color = _parseXColor(slots[index]);
      if (color == null) continue;
      switch (specialIndex) {
        case 0:
          _foregroundColorOverride = color;
        case 1:
          _backgroundColorOverride = color;
        case 2:
          _cursorColorOverride = color;
      }
    }
  }

  void _restoreIndexedColor(String data) {
    if (data.isEmpty) {
      _indexedColorOverrides.clear();
      return;
    }
    for (final slot in data.split(';')) {
      final index = int.tryParse(slot);
      if (index != null && index >= 0 && index <= 255) {
        _indexedColorOverrides.remove(index);
      }
    }
  }

  void _reportColor(String identifier, int color) {
    final red = (color >> 16) & 0xff;
    final green = (color >> 8) & 0xff;
    final blue = color & 0xff;
    String channel(int value) {
      final hex = value.toRadixString(16).padLeft(2, '0');
      return '$hex$hex';
    }

    onData?.call(
      '\u001b]$identifier;rgb:${channel(red)}/${channel(green)}/${channel(blue)}'
      '\u001b\\',
    );
  }

  int _effectiveIndexedColor(int index) =>
      _indexedColorOverrides[index] ?? _themedIndexedColor(index);

  int _effectiveSpecialColor(int index) => switch (index) {
    0 =>
      _foregroundColorOverride ??
          _parseCssRgb(options.theme.foreground) ??
          0xffffff,
    1 =>
      _backgroundColorOverride ??
          _parseCssRgb(options.theme.background) ??
          0x000000,
    _ => _cursorColorOverride ?? _parseCssRgb(options.theme.cursor) ?? 0xffffff,
  };

  int _themedIndexedColor(int index) {
    final themed = <String?>[
      options.theme.black,
      options.theme.red,
      options.theme.green,
      options.theme.yellow,
      options.theme.blue,
      options.theme.magenta,
      options.theme.cyan,
      options.theme.white,
      options.theme.brightBlack,
      options.theme.brightRed,
      options.theme.brightGreen,
      options.theme.brightYellow,
      options.theme.brightBlue,
      options.theme.brightMagenta,
      options.theme.brightCyan,
      options.theme.brightWhite,
    ];
    if (index < 16) {
      return _parseCssRgb(themed[index]) ?? _defaultAnsiColors[index];
    }
    final extended = options.theme.extendedAnsi;
    if (extended != null && index - 16 < extended.length) {
      final parsed = _parseCssRgb(extended[index - 16]);
      if (parsed != null) return parsed;
    }
    if (index < 232) {
      const levels = <int>[0, 95, 135, 175, 215, 255];
      final offset = index - 16;
      final red = levels[offset ~/ 36];
      final green = levels[offset % 36 ~/ 6];
      final blue = levels[offset % 6];
      return red << 16 | green << 8 | blue;
    }
    final gray = 8 + (index - 232) * 10;
    return gray << 16 | gray << 8 | gray;
  }

  static const List<int> _defaultAnsiColors = <int>[
    0x2e3436,
    0xcc0000,
    0x4e9a06,
    0xc4a000,
    0x3465a4,
    0x75507b,
    0x06989a,
    0xd3d7cf,
    0x555753,
    0xef2929,
    0x8ae234,
    0xfce94f,
    0x729fcf,
    0xad7fa8,
    0x34e2e2,
    0xeeeeec,
  ];

  static int? _parseXColor(String source) {
    final value = source.toLowerCase();
    if (value.startsWith('rgb:')) {
      final channels = value.substring(4).split('/');
      if (channels.length != 3 ||
          channels.any(
            (part) =>
                part.isEmpty ||
                part.length > 4 ||
                !RegExp(r'^[0-9a-f]+$').hasMatch(part),
          )) {
        return null;
      }
      final width = channels.first.length;
      if (channels.any((part) => part.length != width)) return null;
      final maximum = (1 << (width * 4)) - 1;
      final rgb = channels
          .map((part) => (int.parse(part, radix: 16) / maximum * 255).round())
          .toList(growable: false);
      return rgb[0] << 16 | rgb[1] << 8 | rgb[2];
    }
    if (!value.startsWith('#')) return null;
    final hex = value.substring(1);
    if (!const <int>{3, 6, 9, 12}.contains(hex.length) ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(hex)) {
      return null;
    }
    final width = hex.length ~/ 3;
    var color = 0;
    for (var index = 0; index < 3; index++) {
      final raw = int.parse(
        hex.substring(index * width, (index + 1) * width),
        radix: 16,
      );
      final channel = switch (width) {
        1 => raw << 4,
        2 => raw,
        3 => raw >> 4,
        _ => raw >> 8,
      };
      color = color << 8 | channel;
    }
    return color;
  }

  static int? _parseCssRgb(String? source) {
    if (source == null) return null;
    final value = source.trim().toLowerCase();
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 3 || hex.length == 4) {
        final expanded = hex
            .substring(0, 3)
            .split('')
            .map((part) => '$part$part')
            .join();
        return int.tryParse(expanded, radix: 16);
      }
      if (hex.length == 6 || hex.length == 8) {
        return int.tryParse(hex.substring(0, 6), radix: 16);
      }
      return null;
    }
    final match = RegExp(
      r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',
    ).firstMatch(value);
    if (match == null) return null;
    final red = int.parse(match.group(1)!).clamp(0, 255);
    final green = int.parse(match.group(2)!).clamp(0, 255);
    final blue = int.parse(match.group(3)!).clamp(0, 255);
    return red << 16 | green << 8 | blue;
  }

  void _setHyperlink(String data) {
    final separator = data.indexOf(';');
    if (separator < 0) return;
    final parameters = data.substring(0, separator).trim();
    final uri = data.substring(separator + 1);
    if (uri.isEmpty) {
      if (parameters.isEmpty) {
        _attributes.hyperlinkId = 0;
        _attributes.updateExtendedAttributes();
      }
      return;
    }
    _attributes.hyperlinkId = 0;
    _attributes.updateExtendedAttributes();
    String? explicitId;
    for (final parameter in parameters.split(':')) {
      if (parameter.startsWith('id=')) {
        final value = parameter.substring(3);
        if (value.isNotEmpty) explicitId = value;
        break;
      }
    }
    if (explicitId != null) {
      final key = '$explicitId;;$uri';
      final existing = _hyperlinksByExplicitId[key];
      if (existing != null) {
        _attributes.hyperlinkId = existing;
        _attributes.updateExtendedAttributes();
        return;
      }
      final linkId = _nextHyperlinkId++;
      _hyperlinks[linkId] = (id: explicitId, uri: uri);
      _hyperlinksByExplicitId[key] = linkId;
      _attributes.hyperlinkId = linkId;
      _attributes.updateExtendedAttributes();
      return;
    }
    final linkId = _nextHyperlinkId++;
    _hyperlinks[linkId] = (id: null, uri: uri);
    _attributes.hyperlinkId = linkId;
    _attributes.updateExtendedAttributes();
  }

  ({String? id, String uri})? hyperlinkData(int linkId) => _hyperlinks[linkId];

  int _dcs(String source, int start) {
    final terminator = _stringEnd(source, start);
    if (terminator == null) return source.length;
    if (source.startsWith(r'$q', start)) {
      final data = source.substring(start + 2, terminator.start);
      _requestStatusString(data);
    }
    return terminator.end;
  }

  ({int start, int end})? _stringEnd(String source, int start) {
    for (var cursor = start; cursor < source.length; cursor++) {
      final code = source.codeUnitAt(cursor);
      if (code == 0x1b &&
          cursor + 1 < source.length &&
          source.codeUnitAt(cursor + 1) == 0x5c) {
        return (start: cursor, end: cursor + 2);
      }
    }
    return null;
  }

  void _requestStatusString(String data) {
    late final String response;
    switch (data) {
      case '"q':
        response = 'P1\u0024r${_attributes.protected ? 1 : 0}"q';
      case '"p':
        response = 'P1\u0024r61;1"p';
      case 'r':
        response = 'P1\u0024r${marginTop + 1};${marginBottom + 1}r';
      case 'm':
        response = 'P1\u0024r0m';
      case ' q':
        final base = switch (options.cursorStyle) {
          TerminalCursorStyle.block => 2,
          TerminalCursorStyle.underline => 4,
          TerminalCursorStyle.bar => 6,
        };
        response = 'P1\u0024r${base - (options.cursorBlink ? 1 : 0)} q';
      default:
        response = 'P0\u0024r';
    }
    onData?.call('\u001b$response\u001b\\');
  }

  int _consumeString(String source, int start) {
    for (var cursor = start; cursor < source.length; cursor++) {
      final code = source.codeUnitAt(cursor);
      if (code == 0x07) return cursor + 1;
      if (code == 0x1b &&
          cursor + 1 < source.length &&
          source.codeUnitAt(cursor + 1) == 0x5c) {
        return cursor + 2;
      }
    }
    return source.length;
  }

  List<List<int>> _params(String value) {
    if (value.isEmpty) {
      return <List<int>>[
        <int>[0],
      ];
    }
    const maximumParameters = 32;
    const maximumSubParameters = 32;
    final result = <List<int>>[];
    var subParameterCount = 0;
    for (final group in value.split(';').take(maximumParameters)) {
      final parts = group.split(':');
      final parsed = <int>[_boundedParameter(parts.first, 0)];
      final remaining = maximumSubParameters - subParameterCount;
      if (remaining > 0) {
        parsed.addAll(
          parts
              .skip(1)
              .take(remaining)
              .map((part) => _boundedParameter(part, -1)),
        );
        subParameterCount += parsed.length - 1;
      }
      result.add(parsed);
    }
    return result;
  }

  int _boundedParameter(String source, int fallback) =>
      (int.tryParse(source) ?? fallback).clamp(-1, 0x7fffffff);

  int _param(List<List<int>> params, int index, [int fallback = 1]) {
    if (index >= params.length || params[index].isEmpty) return fallback;
    final value = params[index][0];
    return value == 0 ? fallback : value;
  }

  void _control(int code) {
    switch (code) {
      case 0x07:
        onBell?.call();
      case 0x08:
        _backspace();
      case 0x09:
        _tab();
      case 0x0a || 0x0b || 0x0c:
        if (options.convertEol) buffer.active.cursorX = 0;
        _lineFeed();
      case 0x0d:
        buffer.active.cursorX = 0;
        _pendingWrap = false;
      case 0x0e:
        _activeCharset = 1;
        _charset = _g1;
      case 0x0f:
        _activeCharset = 0;
        _charset = _g0;
      case 0x84:
        _index();
      case 0x85:
        _index();
        buffer.active.cursorX = 0;
      case 0x88:
        _tabStops.add(buffer.active.cursorX);
    }
  }

  void _escDispatch(String intermediates, String finalByte) {
    switch ('$intermediates$finalByte') {
      case '7':
        _saveCursor();
      case '8':
        _restoreCursor();
      case 'D':
        _index();
      case 'E':
        _index();
        buffer.active.cursorX = 0;
      case 'H':
        _tabStops.add(buffer.active.cursorX);
      case 'M':
        _reverseIndex();
      case 'c':
        reset();
      case '=':
        appKeypadMode = true;
      case '>':
        appKeypadMode = false;
      case 'n' || '}':
        _activeCharset = 2;
        _charset = _g2;
      case 'o' || '|':
        _activeCharset = 3;
        _charset = _g3;
      case '~':
        _activeCharset = 1;
        _charset = _g1;
      case '#8':
        for (var row = 0; row < _rows; row++) {
          final line = buffer.active.getLine(buffer.active.baseY + row)!;
          for (var column = 0; column < _columns; column++) {
            line.setCell(column, 'E', 1, _attributes);
          }
        }
    }
  }

  void _csiDispatch(
    String prefix,
    String intermediates,
    String finalByte,
    List<List<int>> params,
  ) {
    if (finalByte != 'b') _precedingCharacter = '';
    final amount = _param(params, 0);
    if (intermediates == '!' && finalByte == 'p') {
      softReset();
      return;
    }
    if (intermediates == r'$' && finalByte == 'p') {
      _requestMode(prefix, params);
      return;
    }
    if (intermediates == ' ' && (finalByte == '@' || finalByte == 'A')) {
      _shiftColumns(amount, right: finalByte == 'A');
      return;
    }
    if (intermediates == "'" && (finalByte == '}' || finalByte == '~')) {
      _editColumns(amount, insert: finalByte == '}');
      return;
    }
    if (intermediates == '"' && finalByte == 'q') {
      _attributes.protected = params[0][0] == 1;
      return;
    }
    if (finalByte == 'u' && prefix.isNotEmpty && '=?><'.contains(prefix)) {
      _kittyKeyboard(prefix, params);
      return;
    }
    if (intermediates.isNotEmpty &&
        !(intermediates == ' ' && finalByte == 'q')) {
      return;
    }
    if (prefix.isNotEmpty) {
      final supported = switch (prefix) {
        '?' => const <String>{'J', 'K', 'c', 'h', 'l', 'n'},
        '>' => const <String>{'c', 'q'},
        _ => const <String>{},
      };
      if (!supported.contains(finalByte)) return;
    }
    switch (finalByte) {
      case '@':
        _restrictCursor();
        buffer.active.currentLine.insertCells(
          buffer.active.cursorX,
          amount,
          _eraseAttributes,
        );
      case 'A':
        _moveY(-amount);
      case 'B':
        _moveY(amount);
      case 'e':
        _moveYUnrestricted(amount);
      case 'C' || 'a':
        _moveX(amount);
      case 'D':
        _moveX(-amount);
      case 'E':
        _moveY(amount);
        buffer.active.cursorX = 0;
      case 'F':
        _moveY(-amount);
        buffer.active.cursorX = 0;
      case 'G' || '`':
        _setX(amount - 1);
      case 'H' || 'f':
        if (usesWindowsWrappingHeuristics(options.windowsPty)) {
          updateWindowsModeWrappedState(buffer.active, _columns);
        }
        _setPosition(_param(params, 1) - 1, amount - 1);
      case 'I':
        for (var count = 0; count < amount; count++) {
          _tab();
        }
      case 'J':
        _restrictCursor(maxColumn: _columns);
        _eraseDisplay(params[0][0], prefix == '?');
      case 'K':
        _restrictCursor(maxColumn: _columns);
        _eraseLine(params[0][0], prefix == '?');
      case 'L':
        _restrictCursor();
        if (_inMargins) {
          buffer.active.insertLines(
            buffer.active.cursorY,
            amount,
            _eraseAttributes,
            bottom: marginBottom,
          );
          buffer.active.cursorX = 0;
        }
      case 'M':
        _restrictCursor();
        if (_inMargins) {
          buffer.active.deleteLines(
            buffer.active.cursorY,
            amount,
            _eraseAttributes,
            bottom: marginBottom,
          );
          buffer.active.cursorX = 0;
        }
      case 'P':
        _restrictCursor();
        buffer.active.currentLine.deleteCells(
          buffer.active.cursorX,
          amount,
          _eraseAttributes,
        );
      case 'S':
        for (var count = 0; count < amount; count++) {
          buffer.active.scroll(
            _eraseAttributes,
            top: marginTop,
            bottom: marginBottom,
          );
        }
      case 'T' || '^':
        for (var count = 0; count < amount; count++) {
          buffer.active.reverseScroll(
            TerminalCellAttributes(),
            top: marginTop,
            bottom: marginBottom,
          );
        }
      case 'X':
        _restrictCursor();
        buffer.active.currentLine.erase(
          buffer.active.cursorX,
          buffer.active.cursorX + amount,
          _eraseAttributes,
        );
      case 'Z':
        if (buffer.active.cursorX >= _columns) return;
        for (var count = 0; count < amount; count++) {
          _backTab();
        }
      case 'b':
        if (_precedingCharacter.isNotEmpty) {
          final precedingCharacter = _precedingCharacter;
          for (var count = 0; count < amount; count++) {
            for (final codePoint in precedingCharacter.runes) {
              _print(String.fromCharCode(codePoint), codePoint);
            }
          }
        }
      case 'c':
        if (params[0][0] > 0) return;
        final termName = options.termName;
        if (prefix == '>') {
          if (termName.startsWith('xterm')) {
            onData?.call('\u001b[>0;276;0c');
          } else if (termName.startsWith('rxvt-unicode')) {
            onData?.call('\u001b[>85;95;0c');
          } else if (termName.startsWith('linux')) {
            onData?.call('${params[0][0]}c');
          } else if (termName.startsWith('screen')) {
            onData?.call('\u001b[>83;40003;0c');
          }
        } else if (prefix.isEmpty &&
            (termName.startsWith('xterm') ||
                termName.startsWith('rxvt-unicode') ||
                termName.startsWith('screen'))) {
          onData?.call('\u001b[?1;2c');
        } else if (termName.startsWith('linux')) {
          onData?.call('\u001b[?6c');
        }
      case 'd':
        _setY(amount - 1);
      case 'g':
        if (params[0][0] == 3) {
          _tabStops.clear();
        } else {
          _tabStops.remove(buffer.active.cursorX);
        }
      case 'h' || 'l':
        _setModes(prefix, params, finalByte == 'h');
      case 'm':
        _sgr(params);
      case 'n':
        _deviceStatus(prefix, params[0][0]);
      case 'q':
        if (prefix == '>' && params[0][0] == 0) {
          onData?.call('\u001bP>|xterm.js($xtermVersion)\u001b\\');
        } else if (intermediates == ' ') {
          _setCursorStyle(params[0][0]);
        }
      case 'r':
        if (prefix.isEmpty) _setMargins(params);
      case 's':
        _saveCursor();
      case 't':
        _windowOptions(params);
      case 'u':
        _restoreCursor();
    }
  }

  void _kittyKeyboard(String prefix, List<List<int>> params) {
    if (!options.vtExtensions.kittyKeyboard) return;
    final value = params[0][0];
    switch (prefix) {
      case '=':
        final mode = params.length > 1 && params[1][0] != 0 ? params[1][0] : 1;
        switch (mode) {
          case 1:
            kittyKeyboardFlags = value;
          case 2:
            kittyKeyboardFlags |= value;
          case 3:
            kittyKeyboardFlags &= ~value;
        }
      case '?':
        onData?.call(
          '\u001b[?$kittyKeyboardFlags'
          'u',
        );
      case '>':
        final stack = _activeKittyStack;
        if (stack.length >= 16) stack.removeAt(0);
        stack.add(kittyKeyboardFlags);
        kittyKeyboardFlags = value;
      case '<':
        final count = math.max(1, value == 0 ? 1 : value);
        final stack = _activeKittyStack;
        for (var index = 0; index < count && stack.isNotEmpty; index++) {
          kittyKeyboardFlags = stack.removeLast();
        }
        if (stack.isEmpty && count > 0) kittyKeyboardFlags = 0;
    }
  }

  void _windowOptions(List<List<int>> params) {
    final operation = params[0][0];
    if (!_windowOptionAllowed(operation)) return;
    final second = params.length > 1 ? params[1][0] : 0;
    final dimensions = renderDimensions;
    switch (operation) {
      case 14:
        if (second != 2 && dimensions != null) {
          onData?.call(
            '\u001b[4;${dimensions.height.round()};'
            '${dimensions.width.round()}t',
          );
        }
      case 16:
        if (dimensions != null) {
          onData?.call(
            '\u001b[6;${dimensions.cellHeight.round()};'
            '${dimensions.cellWidth.round()}t',
          );
        }
      case 18:
        onData?.call('\u001b[8;$_rows;${_columns}t');
      case 20:
        onData?.call('\u001b]L$_iconName\u001b\\');
      case 21:
        onData?.call('\u001b]l$_windowTitle\u001b\\');
      case 22:
        if (second == 0 || second == 2) {
          _pushTitle(_windowTitleStack, _windowTitle);
        }
        if (second == 0 || second == 1) {
          _pushTitle(_iconNameStack, _iconName);
        }
      case 23:
        if ((second == 0 || second == 2) && _windowTitleStack.isNotEmpty) {
          _windowTitle = _windowTitleStack.removeLast();
          onTitle?.call(_windowTitle);
        }
        if ((second == 0 || second == 1) && _iconNameStack.isNotEmpty) {
          _iconName = _iconNameStack.removeLast();
        }
    }
  }

  void _pushTitle(List<String> stack, String value) {
    stack.add(value);
    if (stack.length > 10) stack.removeAt(0);
  }

  bool _windowOptionAllowed(int operation) {
    final value = options.windowOptions;
    if (operation > 24) return value.setWinLines;
    return switch (operation) {
      1 => value.restoreWin,
      2 => value.minimizeWin,
      3 => value.setWinPosition,
      4 => value.setWinSizePixels,
      5 => value.raiseWin,
      6 => value.lowerWin,
      7 => value.refreshWin,
      8 => value.setWinSizeChars,
      9 => value.maximizeWin,
      10 => value.fullscreenWin,
      11 => value.getWinState,
      13 => value.getWinPosition,
      14 => value.getWinSizePixels,
      15 => value.getScreenSizePixels,
      16 => value.getCellSizePixels,
      18 => value.getWinSizeChars,
      19 => value.getScreenSizeChars,
      20 => value.getIconTitle,
      21 => value.getWinTitle,
      22 => value.pushTitle,
      23 => value.popTitle,
      24 => value.setWinLines,
      _ => false,
    };
  }

  List<int> get _activeKittyStack =>
      buffer.active.type == TerminalBufferType.alternate
      ? _kittyAlternateStack
      : _kittyMainStack;

  void _switchKittyKeyboardBuffer({required bool alternate}) {
    if (!options.vtExtensions.kittyKeyboard) return;
    if (alternate) {
      _kittyMainFlags = kittyKeyboardFlags;
      kittyKeyboardFlags = _kittyAlternateFlags;
    } else {
      _kittyAlternateFlags = kittyKeyboardFlags;
      kittyKeyboardFlags = _kittyMainFlags;
    }
  }

  void _shiftColumns(int amount, {required bool right}) {
    if (!_inMargins) return;
    for (var row = marginTop; row <= marginBottom; row++) {
      final line = buffer.active.getLine(buffer.active.baseY + row)!;
      if (right) {
        line.insertCells(0, amount, _eraseAttributes);
      } else {
        line.deleteCells(0, amount, _eraseAttributes);
      }
      line.isWrapped = false;
    }
  }

  void _editColumns(int amount, {required bool insert}) {
    if (!_inMargins) return;
    for (var row = marginTop; row <= marginBottom; row++) {
      final line = buffer.active.getLine(buffer.active.baseY + row)!;
      if (insert) {
        line.insertCells(buffer.active.cursorX, amount, _eraseAttributes);
      } else {
        line.deleteCells(buffer.active.cursorX, amount, _eraseAttributes);
      }
      line.isWrapped = false;
    }
  }

  void _print(String value, int codePoint) {
    if (codePoint == 0x00ad) return;
    final mapped = _mapCharset(value);
    if (options.screenReaderMode) onA11yChar?.call(mapped);
    final properties = unicode.active.charProperties(
      codePoint,
      _precedingJoinState,
    );
    final width = TerminalUnicodeHandling.extractWidth(properties);
    final shouldJoin = TerminalUnicodeHandling.extractShouldJoin(properties);
    final oldWidth = shouldJoin
        ? TerminalUnicodeHandling.extractWidth(_precedingJoinState)
        : 0;
    _precedingJoinState = properties;
    if (shouldJoin && buffer.active.cursorX > 0) {
      final line = buffer.active.currentLine;
      final previous = line.getCell(buffer.active.cursorX - 1)!;
      final offset = previous.width == 0 ? 2 : 1;
      final index = math.max(0, buffer.active.cursorX - offset);
      line.joinCell(index, mapped, width);
      buffer.active.cursorX = (buffer.active.cursorX + width - oldWidth).clamp(
        0,
        _columns,
      );
      _precedingCharacter += mapped;
      return;
    }
    if (width == 0) {
      final index = _pendingWrap
          ? buffer.active.cursorX
          : math.max(0, buffer.active.cursorX - 1);
      buffer.active.currentLine.appendCombining(index, value);
      return;
    }
    if (buffer.active.cursorX + width - oldWidth > _columns) {
      if (autoWrapMode) {
        final oldLine = buffer.active.currentLine;
        var oldColumn = buffer.active.cursorX - oldWidth;
        _index();
        buffer.active.cursorX = oldWidth;
        buffer.active.currentLine.isWrapped = true;
        while (oldColumn < _columns) {
          oldLine.setCell(oldColumn++, '', 1, _attributes);
        }
      } else {
        buffer.active.cursorX = _columns - 1;
        if (width == 2) return;
      }
    }
    var column = buffer.active.cursorX;
    if (!autoWrapMode && width == 2 && column == _columns - 1) column--;
    if (insertMode) {
      buffer.active.currentLine.insertCells(column, width, _eraseAttributes);
    } else {
      buffer.active.currentLine.erase(column, column + width, _attributes);
    }
    buffer.active.currentLine.setCell(column, mapped, width, _attributes);
    _precedingCharacter = mapped;
    buffer.active.cursorX = column + width;
  }

  String _mapCharset(String value) {
    if (value.length != 1) return value;
    return _terminalCharsets[_charset]?[value] ?? value;
  }

  void _designateCharset(String slot, String charset) {
    if (slot == '/') return;
    final level = switch (slot) {
      '(' => 0,
      ')' || '-' => 1,
      '*' || '.' => 2,
      '+' => 3,
      _ => 0,
    };
    switch (level) {
      case 0:
        _g0 = charset;
      case 1:
        _g1 = charset;
      case 2:
        _g2 = charset;
      case 3:
        _g3 = charset;
    }
    if (_activeCharset == level) {
      _charset = charset;
    }
  }

  static const Map<String, Map<String, String>> _terminalCharsets =
      <String, Map<String, String>>{
        '0': <String, String>{
          '`': '◆',
          'a': '▒',
          'b': '␉',
          'c': '␌',
          'd': '␍',
          'e': '␊',
          'f': '°',
          'g': '±',
          'h': '␤',
          'i': '␋',
          'j': '┘',
          'k': '┐',
          'l': '┌',
          'm': '└',
          'n': '┼',
          'o': '⎺',
          'p': '⎻',
          'q': '─',
          'r': '⎼',
          's': '⎽',
          't': '├',
          'u': '┤',
          'v': '┴',
          'w': '┬',
          'x': '│',
          'y': '≤',
          'z': '≥',
          '{': 'π',
          '|': '≠',
          '}': '£',
          '~': '·',
        },
        'A': <String, String>{'#': '£'},
        '4': <String, String>{
          '#': '£',
          '@': '¾',
          '[': 'ij',
          r'\': '½',
          ']': '|',
          '{': '¨',
          '|': 'f',
          '}': '¼',
          '~': '´',
        },
        'C': <String, String>{
          '[': 'Ä',
          r'\': 'Ö',
          ']': 'Å',
          '^': 'Ü',
          '`': 'é',
          '{': 'ä',
          '|': 'ö',
          '}': 'å',
          '~': 'ü',
        },
        '5': <String, String>{
          '[': 'Ä',
          r'\': 'Ö',
          ']': 'Å',
          '^': 'Ü',
          '`': 'é',
          '{': 'ä',
          '|': 'ö',
          '}': 'å',
          '~': 'ü',
        },
        'R': <String, String>{
          '#': '£',
          '@': 'à',
          '[': '°',
          r'\': 'ç',
          ']': '§',
          '{': 'é',
          '|': 'ù',
          '}': 'è',
          '~': '¨',
        },
        'Q': <String, String>{
          '@': 'à',
          '[': 'â',
          r'\': 'ç',
          ']': 'ê',
          '^': 'î',
          '`': 'ô',
          '{': 'é',
          '|': 'ù',
          '}': 'è',
          '~': 'û',
        },
        'K': <String, String>{
          '@': '§',
          '[': 'Ä',
          r'\': 'Ö',
          ']': 'Ü',
          '{': 'ä',
          '|': 'ö',
          '}': 'ü',
          '~': 'ß',
        },
        'Y': <String, String>{
          '#': '£',
          '@': '§',
          '[': '°',
          r'\': 'ç',
          ']': 'é',
          '`': 'ù',
          '{': 'à',
          '|': 'ò',
          '}': 'è',
          '~': 'ì',
        },
        'E': <String, String>{
          '@': 'Ä',
          '[': 'Æ',
          r'\': 'Ø',
          ']': 'Å',
          '^': 'Ü',
          '`': 'ä',
          '{': 'æ',
          '|': 'ø',
          '}': 'å',
          '~': 'ü',
        },
        '6': <String, String>{
          '@': 'Ä',
          '[': 'Æ',
          r'\': 'Ø',
          ']': 'Å',
          '^': 'Ü',
          '`': 'ä',
          '{': 'æ',
          '|': 'ø',
          '}': 'å',
          '~': 'ü',
        },
        'Z': <String, String>{
          '#': '£',
          '@': '§',
          '[': '¡',
          r'\': 'Ñ',
          ']': '¿',
          '{': '°',
          '|': 'ñ',
          '}': 'ç',
        },
        'H': <String, String>{
          '@': 'É',
          '[': 'Ä',
          r'\': 'Ö',
          ']': 'Å',
          '^': 'Ü',
          '`': 'é',
          '{': 'ä',
          '|': 'ö',
          '}': 'å',
          '~': 'ü',
        },
        '7': <String, String>{
          '@': 'É',
          '[': 'Ä',
          r'\': 'Ö',
          ']': 'Å',
          '^': 'Ü',
          '`': 'é',
          '{': 'ä',
          '|': 'ö',
          '}': 'å',
          '~': 'ü',
        },
        '=': <String, String>{
          '#': 'ù',
          '@': 'à',
          '[': 'é',
          r'\': 'ç',
          ']': 'ê',
          '^': 'î',
          '_': 'è',
          '`': 'ô',
          '{': 'ä',
          '|': 'ö',
          '}': 'ü',
          '~': 'û',
        },
      };

  void _backspace() {
    buffer.active.cursorX = buffer.active.cursorX.clamp(
      0,
      reverseWraparoundMode ? _columns : _columns - 1,
    );
    if (buffer.active.cursorX > 0) {
      buffer.active.cursorX--;
    } else if (reverseWraparoundMode &&
        autoWrapMode &&
        _inMargins &&
        buffer.active.cursorY > marginTop &&
        buffer.active.currentLine.isWrapped) {
      buffer.active.currentLine.isWrapped = false;
      buffer.active.cursorY--;
      buffer.active.cursorX = _columns - 1;
      final cell = buffer.active.currentLine.getCell(buffer.active.cursorX);
      if (cell != null && cell.width == 1 && cell.chars.isEmpty) {
        buffer.active.cursorX--;
      }
    }
  }

  void _tab() {
    if (buffer.active.cursorX >= _columns) return;
    final originalColumn = buffer.active.cursorX;
    for (var column = buffer.active.cursorX + 1; column < _columns; column++) {
      if (_tabStops.contains(column)) {
        buffer.active.cursorX = column;
        if (options.screenReaderMode) {
          onA11yTab?.call(buffer.active.cursorX - originalColumn);
        }
        return;
      }
    }
    buffer.active.cursorX = _columns - 1;
    if (options.screenReaderMode) {
      onA11yTab?.call(buffer.active.cursorX - originalColumn);
    }
  }

  void _backTab() {
    for (var column = buffer.active.cursorX - 1; column >= 0; column--) {
      if (_tabStops.contains(column)) {
        buffer.active.cursorX = column;
        return;
      }
    }
    buffer.active.cursorX = 0;
  }

  void _lineFeed() {
    _index();
    if (lineFeedMode) buffer.active.cursorX = 0;
    if (buffer.active.cursorX >= _columns) buffer.active.cursorX--;
    buffer.active.currentLine.isWrapped = false;
    if (usesWindowsWrappingHeuristics(options.windowsPty)) {
      updateWindowsModeWrappedState(buffer.active, _columns);
    }
    onLineFeed?.call();
  }

  void _index() {
    _pendingWrap = false;
    _restrictCursor();
    if (buffer.active.cursorY == marginBottom) {
      buffer.active.scroll(
        _eraseAttributes,
        top: marginTop,
        bottom: marginBottom,
      );
    } else if (buffer.active.cursorY < _rows - 1) {
      buffer.active.cursorY++;
    }
    _restrictCursor();
  }

  void _reverseIndex() {
    _pendingWrap = false;
    _restrictCursor();
    if (buffer.active.cursorY == marginTop) {
      buffer.active.reverseScroll(
        _eraseAttributes,
        top: marginTop,
        bottom: marginBottom,
      );
    } else if (buffer.active.cursorY > 0) {
      buffer.active.cursorY--;
    }
    _restrictCursor();
  }

  bool get _inMargins =>
      buffer.active.cursorY >= marginTop &&
      buffer.active.cursorY <= marginBottom;

  void _moveX(int amount) {
    _pendingWrap = false;
    _restrictCursor();
    buffer.active.cursorX = (buffer.active.cursorX + amount).clamp(
      0,
      _columns - 1,
    );
  }

  void _moveY(int amount) {
    _pendingWrap = false;
    _restrictCursor();
    final minimum = buffer.active.cursorY >= marginTop ? marginTop : 0;
    final maximum = buffer.active.cursorY <= marginBottom
        ? marginBottom
        : _rows - 1;
    buffer.active.cursorY = (buffer.active.cursorY + amount).clamp(
      minimum,
      maximum,
    );
  }

  void _moveYUnrestricted(int amount) {
    _restrictCursor();
    buffer.active.cursorY = (buffer.active.cursorY + amount).clamp(
      originMode ? marginTop : 0,
      originMode ? marginBottom : _rows - 1,
    );
  }

  void _restrictCursor({int? maxColumn}) {
    buffer.active.cursorX = buffer.active.cursorX.clamp(
      0,
      maxColumn ?? _columns - 1,
    );
    buffer.active.cursorY = buffer.active.cursorY.clamp(
      originMode ? marginTop : 0,
      originMode ? marginBottom : _rows - 1,
    );
  }

  void _setX(int column) {
    _pendingWrap = false;
    _restrictCursor();
    buffer.active.cursorX = column.clamp(0, _columns - 1);
  }

  void _setY(int row) {
    _pendingWrap = false;
    _restrictCursor();
    final adjusted = originMode ? row + marginTop : row;
    buffer.active.cursorY = adjusted.clamp(
      originMode ? marginTop : 0,
      originMode ? marginBottom : _rows - 1,
    );
  }

  void _setPosition(int column, int row) {
    _setY(row);
    _setX(column);
  }

  void _eraseDisplay(int mode, bool selective) {
    final active = buffer.active;
    switch (mode) {
      case 0:
        active.currentLine.erase(
          active.cursorX,
          _columns,
          _eraseAttributes,
          respectProtection: selective,
        );
        for (var row = active.cursorY + 1; row < _rows; row++) {
          active
              .getLine(active.baseY + row)!
              .erase(
                0,
                _columns,
                _eraseAttributes,
                respectProtection: selective,
              );
        }
      case 1:
        for (var row = 0; row < active.cursorY; row++) {
          active
              .getLine(active.baseY + row)!
              .erase(
                0,
                _columns,
                _eraseAttributes,
                respectProtection: selective,
              );
        }
        active.currentLine.erase(
          0,
          active.cursorX + 1,
          _eraseAttributes,
          respectProtection: selective,
        );
      case 2:
        if (options.scrollOnEraseInDisplay && !selective) {
          var lastContentRow = _rows - 1;
          while (lastContentRow >= 0 &&
              active
                      .getLine(active.baseY + lastContentRow)!
                      .getTrimmedLength() ==
                  0) {
            lastContentRow--;
          }
          for (var row = lastContentRow; row >= 0; row--) {
            active.scroll(_eraseAttributes);
          }
        } else {
          for (var row = 0; row < _rows; row++) {
            active.getLine(active.baseY + row)!
              ..erase(
                0,
                _columns,
                _eraseAttributes,
                respectProtection: selective,
              )
              ..isWrapped = false;
          }
        }
      case 3:
        if (identical(active, buffer.normal)) {
          active.clearScrollback();
        }
    }
  }

  void _eraseLine(int mode, bool selective) {
    final line = buffer.active.currentLine;
    switch (mode) {
      case 0:
        line.erase(
          buffer.active.cursorX,
          _columns,
          _eraseAttributes,
          respectProtection: selective,
        );
        if (buffer.active.cursorX == 0) line.isWrapped = false;
      case 1:
        line.erase(
          0,
          buffer.active.cursorX + 1,
          _eraseAttributes,
          respectProtection: selective,
        );
      case 2:
        line.erase(0, _columns, _eraseAttributes, respectProtection: selective);
        line.isWrapped = false;
    }
  }

  void _sgr(List<List<int>> params) {
    final values = params.isEmpty
        ? <List<int>>[
            <int>[0],
          ]
        : params;
    for (var index = 0; index < values.length; index++) {
      final group = values[index];
      final code = group[0];
      switch (code) {
        case 0:
          _attributes = TerminalCellAttributes(
            hyperlinkId: _attributes.hyperlinkId,
          );
        case 1:
          _attributes.bold = true;
        case 2:
          _attributes.dim = true;
        case 3:
          _attributes.italic = true;
        case 4:
          _attributes.underline = group.length > 1
              ? switch (group[1]) {
                  0 => TerminalUnderlineStyle.none,
                  1 => TerminalUnderlineStyle.single,
                  2 => TerminalUnderlineStyle.double,
                  3 => TerminalUnderlineStyle.curly,
                  4 => TerminalUnderlineStyle.dotted,
                  5 => TerminalUnderlineStyle.dashed,
                  _ => TerminalUnderlineStyle.single,
                }
              : TerminalUnderlineStyle.single;
        case 5 || 6:
          _attributes.blink = true;
        case 7:
          _attributes.inverse = true;
        case 8:
          _attributes.invisible = true;
        case 9:
          _attributes.strikethrough = true;
        case 21:
          _attributes.underline = TerminalUnderlineStyle.double;
        case 22:
          _attributes
            ..bold = false
            ..dim = false;
        case 221:
          if (options.vtExtensions.kittySgrBoldFaintControl) {
            _attributes.bold = false;
          }
        case 222:
          if (options.vtExtensions.kittySgrBoldFaintControl) {
            _attributes.dim = false;
          }
        case 23:
          _attributes.italic = false;
        case 24:
          _attributes.underline = TerminalUnderlineStyle.none;
        case 25:
          _attributes.blink = false;
        case 27:
          _attributes.inverse = false;
        case 28:
          _attributes.invisible = false;
        case 29:
          _attributes.strikethrough = false;
        case >= 30 && <= 37:
          _attributes.foreground = TerminalCellColor.palette(code - 30);
        case 38:
          final parsed = _extendedColor(params, index);
          _attributes.foreground = parsed.color;
          index = parsed.lastIndex;
        case 39:
          _attributes.foreground = const TerminalCellColor.defaultColor();
        case >= 40 && <= 47:
          _attributes.background = TerminalCellColor.palette(code - 40);
        case 48:
          final parsed = _extendedColor(params, index);
          _attributes.background = parsed.color;
          index = parsed.lastIndex;
        case 49:
          _attributes.background = const TerminalCellColor.defaultColor();
        case 53:
          _attributes.overline = true;
        case 55:
          _attributes.overline = false;
        case 58:
          final parsed = _extendedColor(params, index);
          _attributes.underlineColor = parsed.color;
          index = parsed.lastIndex;
        case 59:
          _attributes.underlineColor = const TerminalCellColor.defaultColor();
        case >= 90 && <= 97:
          _attributes.foreground = TerminalCellColor.palette(code - 90 + 8);
        case >= 100 && <= 107:
          _attributes.background = TerminalCellColor.palette(code - 100 + 8);
      }
    }
    _attributes.updateExtendedAttributes();
    _eraseAttributes = TerminalCellAttributes(
      background: _attributes.background,
    );
  }

  ({TerminalCellColor color, int lastIndex}) _extendedColor(
    List<List<int>> params,
    int index,
  ) {
    final group = params[index];
    int component(int value) => value < 0 ? 0 : value.clamp(0, 255);
    if (group.length >= 2 && group[1] == 5) {
      return (
        color: TerminalCellColor.palette(
          component(group.length > 2 ? group[2] : 0),
        ),
        lastIndex: index,
      );
    }
    if (group.length >= 2 && group[1] == 2) {
      return (
        color: TerminalCellColor.rgb(
          component(group.length > 3 ? group[3] : 0),
          component(group.length > 4 ? group[4] : 0),
          component(group.length > 5 ? group[5] : 0),
        ),
        lastIndex: index,
      );
    }
    if (index + 1 < params.length) {
      final next = params[index + 1];
      if (next.length > 1 && next[0] == 2) {
        return (
          color: TerminalCellColor.rgb(
            component(next.length > 2 ? next[2] : 0),
            component(next.length > 3 ? next[3] : 0),
            component(next.length > 4 ? next[4] : 0),
          ),
          lastIndex: index + 1,
        );
      }
      if (next.length >= 2 && next[0] == 5) {
        return (
          color: TerminalCellColor.palette(next[1].clamp(0, 255)),
          lastIndex: index + 1,
        );
      }
      if (next[0] == 2) {
        final components = <int>[];
        var lastIndex = index + 1;
        for (
          var parameterIndex = index + 2;
          parameterIndex < params.length && components.length < 3;
          parameterIndex++
        ) {
          components.addAll(params[parameterIndex].map(component));
          lastIndex = parameterIndex;
        }
        while (components.length < 3) {
          components.add(0);
        }
        return (
          color: TerminalCellColor.rgb(
            components[0],
            components[1],
            components[2],
          ),
          lastIndex: lastIndex,
        );
      }
    }
    if (index + 1 < params.length && _param(params, index + 1, 0) == 5) {
      return (
        color: TerminalCellColor.palette(
          _param(params, index + 2, 0).clamp(0, 255),
        ),
        lastIndex: math.min(index + 2, params.length - 1),
      );
    }
    if (index + 1 < params.length && _param(params, index + 1, 0) == 2) {
      return (
        color: TerminalCellColor.rgb(
          _param(params, index + 2, 0).clamp(0, 255),
          _param(params, index + 3, 0).clamp(0, 255),
          _param(params, index + 4, 0).clamp(0, 255),
        ),
        lastIndex: math.min(index + 4, params.length - 1),
      );
    }
    return (color: const TerminalCellColor.defaultColor(), lastIndex: index);
  }

  void _setModes(String prefix, List<List<int>> params, bool enabled) {
    for (final group in params) {
      final mode = group[0];
      if (prefix != '?') {
        if (mode == 4) insertMode = enabled;
        if (mode == 20) {
          lineFeedMode = enabled;
          options.convertEol = enabled;
        }
        continue;
      }
      switch (mode) {
        case 1:
          cursorKeysMode = enabled;
        case 2:
          if (enabled) {
            _g0 = 'B';
            _g1 = 'B';
            _g2 = 'B';
            _g3 = 'B';
            _charset = 'B';
            _activeCharset = 0;
          }
        case 3:
          if (options.windowOptions.setWinLines) {
            resize(enabled ? 132 : 80, _rows);
            buffer.active.clear();
            _setPosition(0, 0);
          }
        case 6:
          originMode = enabled;
          _setPosition(0, 0);
        case 7:
          autoWrapMode = enabled;
        case 9:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.x10
              : TerminalMouseTrackingMode.none;
        case 12:
          if (options.quirks.allowSetCursorBlink) {
            options.cursorBlink = enabled;
          }
        case 25:
          cursorVisibleMode = enabled;
        case 45:
          reverseWraparoundMode = enabled;
        case 66:
          appKeypadMode = enabled;
        case 47 || 1047:
          if (enabled) {
            _switchKittyKeyboardBuffer(alternate: true);
            buffer.useAlternate(_eraseAttributes);
          } else {
            _switchKittyKeyboardBuffer(alternate: false);
            buffer.useNormal();
          }
        case 1000:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.vt200
              : TerminalMouseTrackingMode.none;
        case 1002:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.drag
              : TerminalMouseTrackingMode.none;
        case 1003:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.any
              : TerminalMouseTrackingMode.none;
        case 1004:
          reportFocusMode = enabled;
          if (enabled) onRequestSendFocus?.call();
        case 1005:
          // Removed by xterm.js; consume without changing mouse encoding.
          continue;
        case 1006:
          sgrMouseMode = enabled;
          sgrPixelsMouseMode = false;
        case 1015:
          // Removed by xterm.js; consume without changing mouse encoding.
          continue;
        case 1016:
          sgrPixelsMouseMode = enabled;
          sgrMouseMode = false;
        case 1007:
          alternateScrollMode = enabled;
        case 1048:
          enabled ? _saveCursor() : _restoreCursor();
        case 1049:
          if (enabled) {
            _saveCursor();
            _switchKittyKeyboardBuffer(alternate: true);
            buffer.useAlternate(_eraseAttributes);
          } else {
            _switchKittyKeyboardBuffer(alternate: false);
            buffer.useNormal();
            _restoreCursor();
          }
        case 2004:
          bracketedPasteMode = enabled;
        case 2026:
          synchronizedOutputMode = enabled;
        case 2031:
          if (options.vtExtensions.colorSchemeQuery) {
            colorSchemeUpdates = enabled;
          }
        case 9001:
          if (options.vtExtensions.win32InputMode) {
            win32InputMode = enabled;
          }
      }
    }
  }

  void _deviceStatus(String prefix, int mode) {
    if (mode == 5) {
      onData?.call(prefix == '?' ? '\u001b[?0n' : '\u001b[0n');
    } else if (mode == 6) {
      final row = buffer.active.cursorY + 1;
      final column = buffer.active.cursorX + 1;
      onData?.call(
        prefix == '?' ? '\u001b[?$row;${column}R' : '\u001b[$row;${column}R',
      );
    } else if (prefix == '?' &&
        mode == 996 &&
        options.vtExtensions.colorSchemeQuery) {
      final background = cssToColor(options.theme.background ?? '#000000');
      final foreground = cssToColor(options.theme.foreground ?? '#ffffff');
      final bgLuminance = _relativeLuminance(background.rgba >> 8);
      final fgLuminance = _relativeLuminance(foreground.rgba >> 8);
      onData?.call('\u001b[?997;${bgLuminance < fgLuminance ? 1 : 2}n');
    }
  }

  double _relativeLuminance(int rgb) {
    double channel(int value) {
      final normalized = value / 255;
      return normalized <= 0.03928
          ? normalized / 12.92
          : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(rgb >> 16 & 0xff) +
        0.7152 * channel(rgb >> 8 & 0xff) +
        0.0722 * channel(rgb & 0xff);
  }

  void _requestMode(String prefix, List<List<int>> params) {
    final private = prefix == '?';
    final mode = params[0][0];
    final state = private ? _privateModeState(mode) : _ansiModeState(mode);
    onData?.call('\u001b[${private ? '?' : ''}$mode;$state\u0024y');
  }

  int _ansiModeState(int mode) => switch (mode) {
    2 => 4,
    4 => insertMode ? 1 : 2,
    12 => 3,
    20 => lineFeedMode ? 1 : 2,
    _ => 0,
  };

  int _privateModeState(int mode) => switch (mode) {
    1 => cursorKeysMode ? 1 : 2,
    3 when options.windowOptions.setWinLines => switch (_columns) {
      80 => 2,
      132 => 1,
      _ => 0,
    },
    6 => originMode ? 1 : 2,
    7 => autoWrapMode ? 1 : 2,
    8 => 3,
    9 => mouseMode == TerminalMouseTrackingMode.x10 ? 1 : 2,
    12 => options.cursorBlink ? 1 : 2,
    25 => cursorVisibleMode ? 1 : 2,
    45 => reverseWraparoundMode ? 1 : 2,
    66 => appKeypadMode ? 1 : 2,
    67 => 4,
    1000 => mouseMode == TerminalMouseTrackingMode.vt200 ? 1 : 2,
    1002 => mouseMode == TerminalMouseTrackingMode.drag ? 1 : 2,
    1003 => mouseMode == TerminalMouseTrackingMode.any ? 1 : 2,
    1004 => reportFocusMode ? 1 : 2,
    1005 || 1015 => 4,
    1006 => sgrMouseMode ? 1 : 2,
    1016 => sgrPixelsMouseMode ? 1 : 2,
    1048 => 1,
    47 ||
    1047 ||
    1049 => buffer.active.type == TerminalBufferType.alternate ? 1 : 2,
    2004 => bracketedPasteMode ? 1 : 2,
    2026 => synchronizedOutputMode ? 1 : 2,
    9001 when options.vtExtensions.win32InputMode => win32InputMode ? 1 : 2,
    _ => 0,
  };

  void _setMargins(List<List<int>> params) {
    final top = _param(params, 0) - 1;
    final requestedBottom = params.length > 1 ? params[1][0] : 0;
    final bottom = requestedBottom == 0 || requestedBottom > _rows
        ? _rows - 1
        : requestedBottom - 1;
    if (bottom <= top) return;
    marginTop = top;
    marginBottom = bottom;
    _setPosition(0, 0);
  }

  void _setCursorStyle(int value) {
    if (value == 0) {
      cursorStyleOverride = null;
      cursorBlinkOverride = null;
      return;
    }
    cursorStyleOverride = switch (value) {
      1 || 2 => TerminalCursorStyle.block,
      3 || 4 => TerminalCursorStyle.underline,
      5 || 6 => TerminalCursorStyle.bar,
      _ => cursorStyleOverride,
    };
    if (value >= 1 && value <= 6) cursorBlinkOverride = value.isOdd;
  }

  void _saveCursor() {
    final active = buffer.active;
    active
      ..savedCursorX = active.cursorX
      ..savedCursorY = active.cursorY
      ..savedCursorAbsoluteY = active.baseY + active.cursorY
      ..savedAttributes = _attributes.copy()
      ..savedCharsets = <String>[_g0, _g1, _g2, _g3]
      ..savedCharsetLevel = _activeCharset;
    _savedOriginMode = originMode;
    _savedAutoWrapMode = autoWrapMode;
    _savedMarginTop = marginTop;
    _savedMarginBottom = marginBottom;
  }

  void _restoreCursor() {
    final active = buffer.active;
    active
      ..cursorX = active.savedCursorX.clamp(0, _columns - 1)
      ..cursorY = (active.savedCursorAbsoluteY - active.baseY).clamp(
        0,
        _rows - 1,
      );
    _attributes = active.savedAttributes.copy();
    _g0 = active.savedCharsets[0];
    _g1 = active.savedCharsets[1];
    _g2 = active.savedCharsets[2];
    _g3 = active.savedCharsets[3];
    _activeCharset = active.savedCharsetLevel;
    _charset = active.savedCharsets[_activeCharset];
    originMode = _savedOriginMode;
    autoWrapMode = _savedAutoWrapMode;
    marginTop = _savedMarginTop.clamp(0, _rows - 1);
    marginBottom = _savedMarginBottom.clamp(marginTop, _rows - 1);
    _pendingWrap = false;
  }

  void resize(int columns, int rows) {
    _columns = columns;
    _rows = rows;
    marginTop = 0;
    marginBottom = rows - 1;
    buffer.resize(
      columns,
      rows,
      _eraseAttributes,
      reflowCursorLine: options.reflowCursorLine,
      windowsPty: options.windowsPty,
    );
    _resetTabStops();
  }

  void _resetTabStops() {
    _tabStops
      ..clear()
      ..addAll(<int>[
        for (
          var column = options.tabStopWidth;
          column < _columns;
          column += options.tabStopWidth
        )
          column,
      ]);
  }

  void handleOptionChange(String name) {
    switch (name) {
      case 'scrollback':
        buffer.normal.updateScrollback(options.scrollback);
        return;
      case 'tabStopWidth':
        _resetTabStops();
        return;
      case 'theme':
        _indexedColorOverrides.clear();
        _foregroundColorOverride = null;
        _backgroundColorOverride = null;
        _cursorColorOverride = null;
        return;
    }
  }

  void softReset() {
    insertMode = false;
    originMode = false;
    autoWrapMode = true;
    cursorVisibleMode = true;
    cursorKeysMode = false;
    appKeypadMode = false;
    reportFocusMode = false;
    bracketedPasteMode = false;
    colorSchemeUpdates = false;
    reverseWraparoundMode = false;
    synchronizedOutputMode = false;
    cursorStyleOverride = null;
    cursorBlinkOverride = null;
    mouseMode = TerminalMouseTrackingMode.none;
    marginTop = 0;
    marginBottom = _rows - 1;
    _attributes = TerminalCellAttributes();
    _eraseAttributes = TerminalCellAttributes();
    _g0 = 'B';
    _g1 = 'B';
    _g2 = 'B';
    _g3 = 'B';
    _charset = 'B';
    _activeCharset = 0;
    buffer.active
      ..savedCursorX = 0
      ..savedCursorY = 0
      ..savedCursorAbsoluteY = 0
      ..savedAttributes = TerminalCellAttributes()
      ..savedCharsets = <String>['B', 'B', 'B', 'B']
      ..savedCharsetLevel = 0;
    _setPosition(0, 0);
  }

  void reset() {
    buffer
      ..useNormal()
      ..normal.clear()
      ..alternate.clear();
    _g0 = 'B';
    _g1 = 'B';
    _g2 = 'B';
    _g3 = 'B';
    _charset = 'B';
    _activeCharset = 0;
    _precedingCharacter = '';
    _precedingJoinState = 0;
    lineFeedMode = false;
    win32InputMode = false;
    kittyKeyboardFlags = 0;
    _kittyMainFlags = 0;
    _kittyAlternateFlags = 0;
    _kittyMainStack.clear();
    _kittyAlternateStack.clear();
    softReset();
    _resetTabStops();
  }
}
