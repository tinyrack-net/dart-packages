import 'dart:typed_data';

/// Converts one legal UTF-32 code point to Dart's UTF-16 string form.
String stringFromCodePoint(int codePoint) {
  if (codePoint > 0xffff) {
    final value = codePoint - 0x10000;
    return String.fromCharCodes(<int>[
      (value >> 10) + 0xd800,
      (value % 0x400) + 0xdc00,
    ]);
  }
  return String.fromCharCode(codePoint);
}

/// Converts UTF-32 code points in `[start, end)` to a UTF-16 string.
String utf32ToString(Uint32List data, {int start = 0, int? end}) {
  final stop = end ?? data.length;
  final result = StringBuffer();
  for (var index = start; index < stop; index++) {
    var codePoint = data[index];
    if (codePoint > 0xffff) {
      codePoint -= 0x10000;
      result
        ..writeCharCode((codePoint >> 10) + 0xd800)
        ..writeCharCode((codePoint % 0x400) + 0xdc00);
    } else {
      result.writeCharCode(codePoint);
    }
  }
  return result.toString();
}

/// Streaming UTF-16-to-UTF-32 decoder matching xterm.js `StringToUtf32`.
///
/// Lone surrogates are retained as UCS-2 code units, just as JavaScript
/// strings retain them.
final class StringToUtf32 {
  int _interim = 0;

  /// Clears a pending high surrogate.
  void clear() {
    _interim = 0;
  }

  /// Decodes [input] into [target] and returns the number of values written.
  int decode(String input, Uint32List target) {
    final length = input.length;
    if (length == 0) return 0;

    var size = 0;
    var startPosition = 0;

    if (_interim != 0) {
      final second = input.codeUnitAt(startPosition++);
      if (second >= 0xdc00 && second <= 0xdfff) {
        target[size++] =
            (_interim - 0xd800) * 0x400 + second - 0xdc00 + 0x10000;
      } else {
        target[size++] = _interim;
        target[size++] = second;
      }
      _interim = 0;
    }

    for (var index = startPosition; index < length; index++) {
      final code = input.codeUnitAt(index);
      if (code >= 0xd800 && code <= 0xdbff) {
        index++;
        if (index >= length) {
          _interim = code;
          return size;
        }
        final second = input.codeUnitAt(index);
        if (second >= 0xdc00 && second <= 0xdfff) {
          target[size++] = (code - 0xd800) * 0x400 + second - 0xdc00 + 0x10000;
        } else {
          target[size++] = code;
          target[size++] = second;
        }
        continue;
      }
      if (code == 0xfeff) continue;
      target[size++] = code;
    }
    return size;
  }
}

/// Streaming UTF-8-to-UTF-32 decoder matching xterm.js `Utf8ToUtf32`.
final class Utf8ToUtf32 {
  /// Up to three bytes retained from an incomplete UTF-8 sequence.
  final Uint8List interim = Uint8List(3);

  /// Clears pending bytes.
  void clear() {
    interim.fillRange(0, interim.length, 0);
  }

  /// Decodes [input] into [target] and returns the number of values written.
  int decode(Uint8List input, Uint32List target) {
    final length = input.length;
    if (length == 0) return 0;

    var size = 0;
    var startPosition = 0;

    if (interim[0] != 0) {
      var discardInterim = false;
      var codePoint = interim[0];
      codePoint &= (codePoint & 0xe0) == 0xc0
          ? 0x1f
          : (codePoint & 0xf0) == 0xe0
          ? 0x0f
          : 0x07;
      var position = 1;
      while (position < interim.length && interim[position] != 0) {
        codePoint = codePoint << 6 | interim[position] & 0x3f;
        position++;
      }
      final type = (interim[0] & 0xe0) == 0xc0
          ? 2
          : (interim[0] & 0xf0) == 0xe0
          ? 3
          : 4;
      final missing = type - position;
      while (startPosition < missing) {
        if (startPosition >= length) return 0;
        final next = input[startPosition++];
        if ((next & 0xc0) != 0x80) {
          startPosition--;
          discardInterim = true;
          break;
        }
        if (position < interim.length) interim[position] = next;
        position++;
        codePoint = codePoint << 6 | next & 0x3f;
      }
      if (!discardInterim) {
        if (type == 2) {
          if (codePoint < 0x80) {
            startPosition--;
          } else {
            target[size++] = codePoint;
          }
        } else if (type == 3) {
          if (codePoint >= 0x0800 &&
              (codePoint < 0xd800 || codePoint > 0xdfff) &&
              codePoint != 0xfeff) {
            target[size++] = codePoint;
          }
        } else if (codePoint >= 0x010000 && codePoint <= 0x10ffff) {
          target[size++] = codePoint;
        }
      }
      clear();
    }

    final fourStop = length - 4;
    var index = startPosition;
    while (index < length) {
      while (index < fourStop &&
          input[index] & 0x80 == 0 &&
          input[index + 1] & 0x80 == 0 &&
          input[index + 2] & 0x80 == 0 &&
          input[index + 3] & 0x80 == 0) {
        target[size++] = input[index];
        target[size++] = input[index + 1];
        target[size++] = input[index + 2];
        target[size++] = input[index + 3];
        index += 4;
      }

      final byte1 = input[index++];
      if (byte1 < 0x80) {
        target[size++] = byte1;
      } else if ((byte1 & 0xe0) == 0xc0) {
        if (index >= length) {
          interim[0] = byte1;
          return size;
        }
        final byte2 = input[index++];
        if ((byte2 & 0xc0) != 0x80) {
          index--;
          continue;
        }
        final codePoint = (byte1 & 0x1f) << 6 | byte2 & 0x3f;
        if (codePoint < 0x80) {
          index--;
          continue;
        }
        target[size++] = codePoint;
      } else if ((byte1 & 0xf0) == 0xe0) {
        if (index >= length) {
          interim[0] = byte1;
          return size;
        }
        final byte2 = input[index++];
        if ((byte2 & 0xc0) != 0x80) {
          index--;
          continue;
        }
        if (index >= length) {
          interim[0] = byte1;
          interim[1] = byte2;
          return size;
        }
        final byte3 = input[index++];
        if ((byte3 & 0xc0) != 0x80) {
          index--;
          continue;
        }
        final codePoint =
            (byte1 & 0x0f) << 12 | (byte2 & 0x3f) << 6 | byte3 & 0x3f;
        if (codePoint < 0x0800 ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff) ||
            codePoint == 0xfeff) {
          continue;
        }
        target[size++] = codePoint;
      } else if ((byte1 & 0xf8) == 0xf0) {
        if (index >= length) {
          interim[0] = byte1;
          return size;
        }
        final byte2 = input[index++];
        if ((byte2 & 0xc0) != 0x80) {
          index--;
          continue;
        }
        if (index >= length) {
          interim[0] = byte1;
          interim[1] = byte2;
          return size;
        }
        final byte3 = input[index++];
        if ((byte3 & 0xc0) != 0x80) {
          index--;
          continue;
        }
        if (index >= length) {
          interim[0] = byte1;
          interim[1] = byte2;
          interim[2] = byte3;
          return size;
        }
        final byte4 = input[index++];
        if ((byte4 & 0xc0) != 0x80) {
          index--;
          continue;
        }
        final codePoint =
            (byte1 & 0x07) << 18 |
            (byte2 & 0x3f) << 12 |
            (byte3 & 0x3f) << 6 |
            byte4 & 0x3f;
        if (codePoint < 0x010000 || codePoint > 0x10ffff) continue;
        target[size++] = codePoint;
      }
    }
    return size;
  }
}
