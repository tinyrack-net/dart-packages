/// Parses an X11 `rgb:` or `#` color into 8-bit channels.
(int, int, int)? parseXColor(String data) {
  if (data.isEmpty) return null;
  var value = data.toLowerCase();
  if (value.startsWith('rgb:')) {
    value = value.substring(4);
    final parts = value.split('/');
    if (parts.length != 3 ||
        parts.any(
          (part) =>
              part.isEmpty ||
              part.length > 4 ||
              part.length != parts.first.length ||
              !_hex.hasMatch(part),
        )) {
      return null;
    }
    final maximum = switch (parts.first.length) {
      1 => 15,
      2 => 255,
      3 => 4095,
      _ => 65535,
    };
    int channel(String part) =>
        (int.parse(part, radix: 16) / maximum * 255).round();
    return (channel(parts[0]), channel(parts[1]), channel(parts[2]));
  }
  if (!value.startsWith('#')) return null;
  value = value.substring(1);
  if (!const <int>{3, 6, 9, 12}.contains(value.length) ||
      !_hex.hasMatch(value)) {
    return null;
  }
  final advance = value.length ~/ 3;
  int channel(int index) {
    final channel = int.parse(
      value.substring(advance * index, advance * (index + 1)),
      radix: 16,
    );
    return switch (advance) {
      1 => channel << 4,
      2 => channel,
      3 => channel >> 4,
      _ => channel >> 8,
    };
  }

  return (channel(0), channel(1), channel(2));
}

/// Converts 8-bit [color] channels to an X11 `rgb:` string of [bits].
String toXColorRgb((int, int, int) color, {int bits = 16}) =>
    'rgb:${_pad(color.$1, bits)}/${_pad(color.$2, bits)}/${_pad(color.$3, bits)}';

String _pad(int value, int bits) {
  final source = value.toRadixString(16);
  final padded = source.length < 2 ? '0$source' : source;
  return switch (bits) {
    4 => source[0],
    8 => padded,
    12 => '$padded$padded'.substring(0, 3),
    _ => '$padded$padded',
  };
}

final RegExp _hex = RegExp(r'^[\da-f]+$');
