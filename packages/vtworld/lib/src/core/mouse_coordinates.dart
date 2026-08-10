import 'dart:math' as math;

/// Geometry needed to translate a pointer into terminal-relative coordinates.
final class TerminalElementMetrics {
  /// Creates terminal element offsets and padding.
  const TerminalElementMetrics({
    this.left = 0,
    this.top = 0,
    this.paddingLeft = 0,
    this.paddingTop = 0,
  });

  /// Element left edge in viewport coordinates.
  final double left;

  /// Element top edge in viewport coordinates.
  final double top;

  /// Computed left padding.
  final double paddingLeft;

  /// Computed top padding.
  final double paddingTop;
}

/// Returns pointer coordinates relative to the terminal's padded content box.
(double, double) getCoordsRelativeToElement(
  double clientX,
  double clientY,
  TerminalElementMetrics metrics,
) => (
  clientX - metrics.left - metrics.paddingLeft,
  clientY - metrics.top - metrics.paddingTop,
);

/// Converts viewport pointer coordinates to one-based terminal cell
/// coordinates.
(int, int)? getTerminalCellCoordinates({
  required double clientX,
  required double clientY,
  required TerminalElementMetrics metrics,
  required int columns,
  required int rows,
  required bool hasValidCharacterSize,
  required double cellWidth,
  required double cellHeight,
  bool isSelection = false,
}) {
  if (!hasValidCharacterSize) return null;
  final relative = getCoordsRelativeToElement(clientX, clientY, metrics);
  final selectionOffset = isSelection ? cellWidth / 2 : 0;
  final column = ((relative.$1 + selectionOffset) / cellWidth).ceil();
  final row = (relative.$2 / cellHeight).ceil();
  return (
    math.min(math.max(column, 1), columns + (isSelection ? 1 : 0)),
    math.min(math.max(row, 1), rows),
  );
}
