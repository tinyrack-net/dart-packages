/// Throws when [value] has JavaScript falsy semantics.
T throwIfFalsy<T>(T? value) {
  if (value == null || value == false || value == 0 || value == '') {
    throw StateError('value must not be falsy');
  }
  return value;
}

/// Whether [codepoint] is a Powerline symbol requiring special padding.
bool isPowerlineGlyph(int codepoint) =>
    codepoint >= 0xe0a4 && codepoint <= 0xe0d6;

/// Whether [codepoint] is in the restricted Powerline separator range.
bool isRestrictedPowerlineGlyph(int codepoint) =>
    codepoint >= 0xe0b0 && codepoint <= 0xe0b7;

/// Whether [codepoint] is in one of xterm's renderer emoji ranges.
bool isRendererEmoji(int codepoint) =>
    codepoint >= 0x1f600 && codepoint <= 0x1f64f ||
    codepoint >= 0x1f300 && codepoint <= 0x1f5ff ||
    codepoint >= 0x1f680 && codepoint <= 0x1f6ff ||
    codepoint >= 0x2600 && codepoint <= 0x26ff ||
    codepoint >= 0x2700 && codepoint <= 0x27bf ||
    codepoint >= 0xfe00 && codepoint <= 0xfe0f ||
    codepoint >= 0x1f900 && codepoint <= 0x1f9ff ||
    codepoint >= 0x1f1e6 && codepoint <= 0x1f1ff;

/// Whether an oversized glyph may be horizontally rescaled.
bool allowGlyphRescaling(
  int? codepoint,
  int width,
  double glyphSizeX,
  double deviceCellWidth,
) =>
    width == 1 &&
    glyphSizeX > (deviceCellWidth * 1.5).ceil() &&
    codepoint != null &&
    codepoint > 0xff &&
    !isRendererEmoji(codepoint) &&
    !isPowerlineGlyph(codepoint) &&
    !(codepoint >= 0xe000 && codepoint <= 0xf8ff);

/// Whether a glyph should be painted using the background-color path.
bool treatGlyphAsBackgroundColor(int codepoint) =>
    isPowerlineGlyph(codepoint) || codepoint >= 0x2500 && codepoint <= 0x259f;

/// Computes the underline texture variant offset for the next cell.
int computeNextVariantOffset(
  int cellWidth,
  double lineWidth, [
  int currentOffset = 0,
]) {
  final period = lineWidth.round() * 2;
  return (cellWidth - (period - currentOffset)) % period;
}

/// Mutable two-dimensional renderer extent.
final class RendererExtent {
  /// Creates a zero-sized extent.
  RendererExtent({this.width = 0, this.height = 0});

  /// Horizontal extent.
  double width;

  /// Vertical extent.
  double height;
}

/// Mutable renderer character metrics.
final class RendererCharacterMetrics {
  /// Creates zero-valued character metrics.
  RendererCharacterMetrics({
    this.width = 0,
    this.height = 0,
    this.left = 0,
    this.top = 0,
  });

  /// Glyph width.
  double width;

  /// Glyph height.
  double height;

  /// Horizontal glyph inset.
  double left;

  /// Vertical glyph inset.
  double top;
}

/// Fresh zero-valued CSS and device renderer dimensions.
final class RendererDimensionsState {
  /// Creates a complete zero-valued dimension state.
  RendererDimensionsState()
    : cssCanvas = RendererExtent(),
      cssCell = RendererExtent(),
      deviceCanvas = RendererExtent(),
      deviceCell = RendererExtent(),
      deviceCharacter = RendererCharacterMetrics();

  /// Canvas extent in logical CSS pixels.
  final RendererExtent cssCanvas;

  /// Cell extent in logical CSS pixels.
  final RendererExtent cssCell;

  /// Canvas extent in device pixels.
  final RendererExtent deviceCanvas;

  /// Cell extent in device pixels.
  final RendererExtent deviceCell;

  /// Character metrics in device pixels.
  final RendererCharacterMetrics deviceCharacter;
}

/// Creates fresh renderer dimensions matching xterm's initial state.
RendererDimensionsState createRenderDimensions() => RendererDimensionsState();
