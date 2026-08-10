import 'dart:math' as math;

/// CSS spelling and packed `0xRRGGBBAA` representation of a color.
final class TerminalRgbaColor {
  /// Creates a color from its two xterm representations.
  const TerminalRgbaColor(this.css, this.rgba);

  /// CSS color text.
  final String css;

  /// Packed RGBA channels.
  final int rgba;
}

/// Xterm's transparent sentinel color.
const nullTerminalColor = TerminalRgbaColor('#00000000', 0);

/// Formats one channel as at least two lowercase hexadecimal digits.
String toPaddedHex(int channel) => channel.toRadixString(16).padLeft(2, '0');

/// Converts channels to `#rrggbb` or `#rrggbbaa`.
String channelsToCss(int red, int green, int blue, [int? alpha]) =>
    '#${toPaddedHex(red)}${toPaddedHex(green)}${toPaddedHex(blue)}'
    '${alpha == null ? '' : toPaddedHex(alpha)}';

/// Packs channels as `0xRRGGBBAA`.
int channelsToRgba(int red, int green, int blue, [int alpha = 0xff]) =>
    red << 24 | green << 16 | blue << 8 | alpha;

/// Converts channels to both xterm color representations.
TerminalRgbaColor channelsToColor(int red, int green, int blue, [int? alpha]) =>
    TerminalRgbaColor(
      channelsToCss(red, green, blue, alpha),
      channelsToRgba(red, green, blue, alpha ?? 0xff),
    );

/// Splits packed RGBA channels.
(int, int, int, int) rgbaToChannels(int value) =>
    (value >> 24 & 0xff, value >> 16 & 0xff, value >> 8 & 0xff, value & 0xff);

/// Alpha-composites [foreground] over [background].
int blendRgba(int background, int foreground) {
  final alpha = (foreground & 0xff) / 0xff;
  if (alpha == 1) return foreground;
  int blend(int shift) {
    final front = foreground >> shift & 0xff;
    final back = background >> shift & 0xff;
    return back + ((front - back) * alpha).round();
  }

  return channelsToRgba(blend(24), blend(16), blend(8));
}

/// Alpha-composites [foreground] over [background].
TerminalRgbaColor blendColor(
  TerminalRgbaColor background,
  TerminalRgbaColor foreground,
) {
  if (foreground.rgba & 0xff == 0xff) {
    return TerminalRgbaColor(foreground.css, foreground.rgba);
  }
  final value = blendRgba(background.rgba, foreground.rgba);
  final channels = rgbaToChannels(value);
  return TerminalRgbaColor(
    channelsToCss(channels.$1, channels.$2, channels.$3),
    value,
  );
}

/// Whether [color] has full alpha.
bool isOpaqueColor(TerminalRgbaColor color) => color.rgba & 0xff == 0xff;

/// Returns an opaque copy of [color].
TerminalRgbaColor opaqueColor(TerminalRgbaColor color) {
  final value = color.rgba | 0xff;
  final channels = rgbaToChannels(value);
  return TerminalRgbaColor(
    channelsToCss(channels.$1, channels.$2, channels.$3),
    value,
  );
}

/// Returns [color] with [opacity] replacing its alpha channel.
TerminalRgbaColor colorWithOpacity(TerminalRgbaColor color, double opacity) {
  final alpha = (opacity * 0xff).round();
  final channels = rgbaToChannels(color.rgba);
  return channelsToColor(channels.$1, channels.$2, channels.$3, alpha);
}

/// Parses xterm's non-canvas CSS formats.
TerminalRgbaColor cssToColor(String css) {
  if (RegExp(r'#[\da-f]{3,8}', caseSensitive: false).hasMatch(css)) {
    final hex = css.substring(1);
    if (hex.length == 3 || hex.length == 4) {
      final expanded = hex.split('').map((part) => '$part$part').join();
      final red = int.parse(expanded.substring(0, 2), radix: 16);
      final green = int.parse(expanded.substring(2, 4), radix: 16);
      final blue = int.parse(expanded.substring(4, 6), radix: 16);
      final alpha = expanded.length == 8
          ? int.parse(expanded.substring(6), radix: 16)
          : null;
      return channelsToColor(red, green, blue, alpha);
    }
    if (hex.length == 6) {
      return TerminalRgbaColor(css, int.parse(hex, radix: 16) << 8 | 0xff);
    }
    if (hex.length == 8) {
      return TerminalRgbaColor(css, int.parse(hex, radix: 16));
    }
  }
  final match = RegExp(
    r'rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*'
    r'(?:,\s*(0|1|\d?\.(?:\d+))\s*)?\)',
  ).firstMatch(css);
  if (match != null) {
    final alpha = ((double.tryParse(match.group(4) ?? '') ?? 1) * 0xff).round();
    return channelsToColor(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      alpha,
    );
  }
  if (css == 'transparent') {
    return const TerminalRgbaColor('transparent', 0);
  }
  throw UnsupportedError('css.toColor: Unsupported css format');
}

/// WCAG relative luminance of packed `0xRRGGBB`.
double relativeLuminance(int rgb) =>
    relativeLuminanceChannels(rgb >> 16 & 0xff, rgb >> 8 & 0xff, rgb & 0xff);

/// WCAG relative luminance of individual channels.
double relativeLuminanceChannels(int red, int green, int blue) {
  double linear(int channel) {
    final value = channel / 255;
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722;
}

/// Contrast ratio between two relative luminance values.
double contrastRatio(double first, double second) {
  final low = math.min(first, second);
  final high = math.max(first, second);
  return (high + 0.05) / (low + 0.05);
}

/// Darkens the foreground by xterm's 10% channel steps.
int reduceLuminance(int background, int foreground, double ratio) {
  final bg = rgbaToChannels(background);
  final fg = rgbaToChannels(foreground);
  var red = fg.$1;
  var green = fg.$2;
  var blue = fg.$3;
  while (contrastRatio(
            relativeLuminanceChannels(red, green, blue),
            relativeLuminanceChannels(bg.$1, bg.$2, bg.$3),
          ) <
          ratio &&
      (red > 0 || green > 0 || blue > 0)) {
    red -= (red * 0.1).ceil();
    green -= (green * 0.1).ceil();
    blue -= (blue * 0.1).ceil();
  }
  return channelsToRgba(red, green, blue);
}

/// Lightens the foreground by xterm's 10% channel steps.
int increaseLuminance(int background, int foreground, double ratio) {
  final bg = rgbaToChannels(background);
  final fg = rgbaToChannels(foreground);
  var red = fg.$1;
  var green = fg.$2;
  var blue = fg.$3;
  while (contrastRatio(
            relativeLuminanceChannels(red, green, blue),
            relativeLuminanceChannels(bg.$1, bg.$2, bg.$3),
          ) <
          ratio &&
      (red < 0xff || green < 0xff || blue < 0xff)) {
    red = math.min(0xff, red + ((255 - red) * 0.1).ceil());
    green = math.min(0xff, green + ((255 - green) * 0.1).ceil());
    blue = math.min(0xff, blue + ((255 - blue) * 0.1).ceil());
  }
  return channelsToRgba(red, green, blue);
}

/// Adjusts [foreground] to [ratio], or returns null when already sufficient.
int? ensureContrastRatio(int background, int foreground, double ratio) {
  final backgroundLuminance = relativeLuminance(background >> 8);
  final foregroundLuminance = relativeLuminance(foreground >> 8);
  if (contrastRatio(backgroundLuminance, foregroundLuminance) >= ratio) {
    return null;
  }
  final first = foregroundLuminance < backgroundLuminance
      ? reduceLuminance(background, foreground, ratio)
      : increaseLuminance(background, foreground, ratio);
  final firstRatio = contrastRatio(
    backgroundLuminance,
    relativeLuminance(first >> 8),
  );
  if (firstRatio >= ratio) return first;
  final second = foregroundLuminance < backgroundLuminance
      ? increaseLuminance(background, foreground, ratio)
      : reduceLuminance(background, foreground, ratio);
  final secondRatio = contrastRatio(
    backgroundLuminance,
    relativeLuminance(second >> 8),
  );
  return firstRatio > secondRatio ? first : second;
}

/// Color-object variant of [ensureContrastRatio].
TerminalRgbaColor? ensureColorContrastRatio(
  TerminalRgbaColor background,
  TerminalRgbaColor foreground,
  double ratio,
) {
  final result = ensureContrastRatio(background.rgba, foreground.rgba, ratio);
  if (result == null) return null;
  final channels = rgbaToChannels(result);
  return channelsToColor(channels.$1, channels.$2, channels.$3);
}
