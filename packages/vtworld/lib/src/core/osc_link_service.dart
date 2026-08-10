import 'package:vtworld/src/core/marker.dart';

/// URI and optional OSC 8 string identity.
final class OscLinkData {
  /// Creates link data.
  const OscLinkData({required this.uri, this.id});

  /// Explicit OSC `id=` value.
  final String? id;

  /// Link URI.
  final String uri;
}

final class _OscLinkEntry {
  _OscLinkEntry({
    required this.data,
    required this.linkId,
    required this.key,
    required this.lines,
  });

  final OscLinkData data;
  final int linkId;
  final String? key;
  final List<TerminalMarker> lines;
}

/// Tracks OSC 8 link identities for every buffer line they occupy.
final class OscLinkService {
  /// Creates a service over the active buffer's line and marker operations.
  OscLinkService(this._currentLine, this._addMarker);

  final int Function() _currentLine;
  final TerminalMarker Function(int line) _addMarker;
  final Map<String, _OscLinkEntry> _entriesWithId = <String, _OscLinkEntry>{};
  final Map<int, _OscLinkEntry> _dataByLinkId = <int, _OscLinkEntry>{};
  int _nextId = 1;

  /// Registers [data] at the current buffer line and returns its numeric ID.
  int registerLink(OscLinkData data) {
    final explicitId = data.id;
    if (explicitId != null) {
      final key = '$explicitId;;${data.uri}';
      final match = _entriesWithId[key];
      if (match != null) {
        addLineToLink(match.linkId, _currentLine());
        return match.linkId;
      }
      return _createEntry(data, key);
    }
    return _createEntry(data, null);
  }

  int _createEntry(OscLinkData data, String? key) {
    final marker = _addMarker(_currentLine());
    final entry = _OscLinkEntry(
      data: data,
      linkId: _nextId++,
      key: key,
      lines: <TerminalMarker>[marker],
    );
    marker.onDispose.listen((_) => _removeMarkerFromLink(entry, marker));
    if (key != null) _entriesWithId[key] = entry;
    _dataByLinkId[entry.linkId] = entry;
    return entry.linkId;
  }

  /// Adds [line] to an existing numeric [linkId], ignoring duplicates.
  void addLineToLink(int linkId, int line) {
    final entry = _dataByLinkId[linkId];
    if (entry == null || entry.lines.any((marker) => marker.line == line)) {
      return;
    }
    final marker = _addMarker(line);
    entry.lines.add(marker);
    marker.onDispose.listen((_) => _removeMarkerFromLink(entry, marker));
  }

  /// Returns data for [linkId], or `null` after its final marker is disposed.
  OscLinkData? getLinkData(int linkId) => _dataByLinkId[linkId]?.data;

  void _removeMarkerFromLink(_OscLinkEntry entry, TerminalMarker marker) {
    if (!entry.lines.remove(marker) || entry.lines.isNotEmpty) return;
    final key = entry.key;
    if (key != null) _entriesWithId.remove(key);
    _dataByLinkId.remove(entry.linkId);
  }
}
