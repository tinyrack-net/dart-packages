import 'package:vtworld/src/core/marker.dart';

/// A merged overview-ruler span.
final class TerminalColorZone {
  /// Creates an overview-ruler zone.
  TerminalColorZone({
    required this.color,
    required this.position,
    required this.startBufferLine,
    required this.endBufferLine,
  });

  /// CSS-compatible source color.
  String color;

  /// Horizontal overview-ruler lane.
  TerminalOverviewRulerPosition position;

  /// First absolute buffer line in the span.
  int startBufferLine;

  /// Last absolute buffer line in the span.
  int endBufferLine;
}

/// Pools and merges overview-ruler zones by color and lane.
final class ColorZoneStore {
  final List<TerminalColorZone> _zones = <TerminalColorZone>[];
  final List<TerminalColorZone> _zonePool = <TerminalColorZone>[];
  var _zonePoolIndex = 0;
  Map<TerminalOverviewRulerPosition, int> _linePadding =
      <TerminalOverviewRulerPosition, int>{
        for (final position in TerminalOverviewRulerPosition.values)
          position: 0,
      };

  /// Current merged zones, retaining object identity across [clear].
  List<TerminalColorZone> get zones {
    if (_zonePool.length > _zones.length) {
      _zonePool.removeRange(_zones.length, _zonePool.length);
    }
    return List<TerminalColorZone>.unmodifiable(_zones);
  }

  /// Clears the active zones while retaining pooled objects.
  void clear() {
    _zones.clear();
    _zonePoolIndex = 0;
  }

  /// Adds the overview-ruler information from [decoration].
  void addDecoration(TerminalDecoration decoration) {
    final color = decoration.overviewRulerColor;
    if (color == null) return;
    final line = decoration.marker.line;
    final position = decoration.overviewRulerPosition;
    for (final zone in _zones) {
      if (zone.color != color || zone.position != position) continue;
      if (line >= zone.startBufferLine && line <= zone.endBufferLine) return;
      final padding = _linePadding[position] ?? 0;
      if (line >= zone.startBufferLine - padding &&
          line <= zone.endBufferLine + padding) {
        if (line < zone.startBufferLine) zone.startBufferLine = line;
        if (line > zone.endBufferLine) zone.endBufferLine = line;
        return;
      }
    }
    if (_zonePoolIndex < _zonePool.length) {
      final zone = _zonePool[_zonePoolIndex++]
        ..color = color
        ..position = position
        ..startBufferLine = line
        ..endBufferLine = line;
      _zones.add(zone);
      return;
    }
    final zone = TerminalColorZone(
      color: color,
      position: position,
      startBufferLine: line,
      endBufferLine: line,
    );
    _zones.add(zone);
    _zonePool.add(zone);
    _zonePoolIndex++;
  }

  /// Sets the merge padding for every overview-ruler lane.
  void setPadding(Map<TerminalOverviewRulerPosition, int> padding) {
    _linePadding = Map<TerminalOverviewRulerPosition, int>.of(padding);
  }
}
