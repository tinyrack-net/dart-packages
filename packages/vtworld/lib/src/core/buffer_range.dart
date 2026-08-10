import 'package:vtworld/src/core/buffer.dart';

/// Returns the inclusive linear cell length of [range].
int getRangeLength(TerminalBufferRange range, int bufferColumns) {
  if (range.start.y > range.end.y) {
    throw ArgumentError(
      'Buffer range end (${range.end.x}, ${range.end.y}) cannot be before '
      'start (${range.start.x}, ${range.start.y})',
    );
  }
  return bufferColumns * (range.end.y - range.start.y) +
      (range.end.x - range.start.x + 1);
}
