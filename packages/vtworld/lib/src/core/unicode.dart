import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';

part 'unicode11_tables.g.dart';

/// Supplies character width and grapheme continuation properties.
abstract interface class TerminalUnicodeProvider {
  /// xterm-compatible `version` API.
  String get version;

  /// xterm-compatible `width` API.
  int width(int codePoint);

  /// xterm-compatible `charProperties` API.
  int charProperties(int codePoint, int precedingProperties);
}

/// Registry for selectable Unicode width providers.
final class TerminalUnicodeHandling implements Disposable {
  /// xterm-compatible `TerminalUnicodeHandling` API.
  TerminalUnicodeHandling() {
    register(const Unicode6TerminalProvider());
  }

  final Map<String, TerminalUnicodeProvider> _providers =
      <String, TerminalUnicodeProvider>{};
  String _activeVersion = '6';
  final TerminalEventEmitter<String> _onChange = TerminalEventEmitter<String>();

  /// Fires synchronously whenever [activeVersion] is assigned.
  TerminalEvent<String> get onChange => _onChange.event;

  /// xterm-compatible `register` API.
  void register(TerminalUnicodeProvider provider) {
    _providers[provider.version] = provider;
    if (_activeVersion.isEmpty) activeVersion = provider.version;
  }

  /// xterm-compatible `unmodifiable` API.
  List<String> get versions => List<String>.unmodifiable(_providers.keys);

  /// xterm-compatible `activeVersion` API.
  String get activeVersion => _activeVersion;

  /// xterm-compatible `activeVersion` API.
  set activeVersion(String value) {
    if (!_providers.containsKey(value)) {
      throw ArgumentError.value(value, 'activeVersion', 'is not registered');
    }
    _activeVersion = value;
    _onChange.fire(value);
  }

  /// xterm-compatible `active` API.
  TerminalUnicodeProvider get active => _providers[_activeVersion]!;

  /// Returns the terminal cell width of a UTF-16 [value].
  int getStringCellWidth(String value) {
    var result = 0;
    var precedingProperties = 0;
    final units = value.codeUnits;
    for (var index = 0; index < units.length; index++) {
      var codePoint = units[index];
      if (codePoint >= 0xd800 && codePoint <= 0xdbff) {
        index++;
        if (index >= units.length) return result + active.width(codePoint);
        final second = units[index];
        if (second >= 0xdc00 && second <= 0xdfff) {
          codePoint = (codePoint - 0xd800) * 0x400 + second - 0xdc00 + 0x10000;
        } else {
          result += active.width(second);
        }
      }
      final properties = active.charProperties(codePoint, precedingProperties);
      var width = extractWidth(properties);
      if (extractShouldJoin(properties)) {
        width -= extractWidth(precedingProperties);
      }
      result += width;
      precedingProperties = properties;
    }
    return result;
  }

  @override
  bool get isDisposed => _onChange.isDisposed;

  @override
  void dispose() => _onChange.dispose();

  /// Extracts whether a property joins the preceding cell.
  static bool extractShouldJoin(int value) => value & 1 != 0;

  /// Extracts the encoded terminal cell width.
  static int extractWidth(int value) => value >> 1 & 0x3;

  /// Extracts the provider-specific character state.
  static int extractCharKind(int value) => value >> 3;

  /// Encodes provider state, width and grapheme joining into one value.
  static int createPropertyValue(
    int state,
    int width, {
    bool shouldJoin = false,
  }) => (state & 0xffffff) << 3 | (width & 3) << 1 | (shouldJoin ? 1 : 0);
}

/// Built-in Unicode 6 width provider used by xterm core by default.
final class Unicode6TerminalProvider implements TerminalUnicodeProvider {
  /// Creates the stateless Unicode 6 provider.
  const Unicode6TerminalProvider();

  @override
  String get version => '6';

  @override
  int charProperties(int codePoint, int precedingProperties) {
    var cellWidth = width(codePoint);
    var shouldJoin = cellWidth == 0 && precedingProperties != 0;
    if (shouldJoin) {
      final oldWidth = TerminalUnicodeHandling.extractWidth(
        precedingProperties,
      );
      if (oldWidth == 0) {
        shouldJoin = false;
      } else if (oldWidth > cellWidth) {
        cellWidth = oldWidth;
      }
    }
    return TerminalUnicodeHandling.createPropertyValue(
      0,
      cellWidth,
      shouldJoin: shouldJoin,
    );
  }

  @override
  int width(int codePoint) {
    if (codePoint == 0 ||
        codePoint < 0x20 ||
        codePoint >= 0x7f && codePoint < 0xa0) {
      return 0;
    }
    if (_contains(codePoint, _unicode6BmpCombining) ||
        _contains(codePoint, _unicode6HighCombining)) {
      return 0;
    }
    if (codePoint >= 0x1100 && codePoint <= 0x115f ||
        codePoint == 0x2329 ||
        codePoint == 0x232a ||
        codePoint >= 0x2e80 && codePoint <= 0xa4cf && codePoint != 0x303f ||
        codePoint >= 0xac00 && codePoint <= 0xd7a3 ||
        codePoint >= 0xf900 && codePoint <= 0xfaff ||
        codePoint >= 0xfe10 && codePoint <= 0xfe19 ||
        codePoint >= 0xfe30 && codePoint <= 0xfe6f ||
        codePoint >= 0xff00 && codePoint <= 0xff60 ||
        codePoint >= 0xffe0 && codePoint <= 0xffe6 ||
        codePoint >= 0x20000 && codePoint <= 0x2fffd ||
        codePoint >= 0x30000 && codePoint <= 0x3fffd) {
      return 2;
    }
    return 1;
  }

  static bool _contains(int codePoint, List<(int, int)> ranges) =>
      _inUnicodeRanges(codePoint, ranges);
}

/// Unicode 11 width provider matching xterm's default table at its boundaries.
final class Unicode11TerminalProvider implements TerminalUnicodeProvider {
  /// xterm-compatible `Unicode11TerminalProvider` API.
  const Unicode11TerminalProvider();

  @override
  String get version => '11';

  @override
  int charProperties(int codePoint, int precedingProperties) {
    var cellWidth = width(codePoint);
    var shouldJoin = cellWidth == 0 && precedingProperties != 0;
    if (shouldJoin) {
      final oldWidth = TerminalUnicodeHandling.extractWidth(
        precedingProperties,
      );
      if (oldWidth == 0) {
        shouldJoin = false;
      } else if (oldWidth > cellWidth) {
        cellWidth = oldWidth;
      }
    }
    return TerminalUnicodeHandling.createPropertyValue(
      0,
      cellWidth,
      shouldJoin: shouldJoin,
    );
  }

  @override
  int width(int codePoint) {
    if (codePoint == 0 ||
        codePoint < 0x20 ||
        (codePoint >= 0x7f && codePoint < 0xa0)) {
      return 0;
    }
    if (codePoint < 0x10000) {
      if (_inUnicodeRanges(codePoint, _unicode11BmpCombining)) return 0;
      if (_inUnicodeRanges(codePoint, _unicode11BmpWide)) return 2;
      return 1;
    }
    if (_inUnicodeRanges(codePoint, _unicode11HighCombining)) return 0;
    if (_inUnicodeRanges(codePoint, _unicode11HighWide)) return 2;
    return 1;
  }
}

bool _inUnicodeRanges(int codePoint, List<(int, int)> ranges) {
  var low = 0;
  var high = ranges.length - 1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    final range = ranges[middle];
    if (codePoint < range.$1) {
      high = middle - 1;
    } else if (codePoint > range.$2) {
      low = middle + 1;
    } else {
      return true;
    }
  }
  return false;
}
