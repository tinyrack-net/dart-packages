/// Accumulates chunks without repeated whole-string concatenation.
final class TerminalStringBuilder {
  final List<String> _chunks = <String>[];
  int _length = 0;

  /// UTF-16 code-unit length of all accumulated chunks.
  int get length => _length;

  /// Clears all accumulated data.
  void reset() {
    _chunks.clear();
    _length = 0;
  }

  /// Appends [chunk].
  void append(String chunk) {
    _chunks.add(chunk);
    _length += chunk.length;
  }

  @override
  String toString() => _chunks.join();
}

/// A string builder that rejects payloads beyond a fixed limit.
final class LimitedStringBuilder {
  /// Creates a builder with a maximum UTF-16 length of [limit].
  LimitedStringBuilder(this.limit);

  final TerminalStringBuilder _builder = TerminalStringBuilder();

  /// Maximum accepted length.
  final int limit;

  /// Current accumulated length.
  int get length => _builder.length;

  /// Clears all accumulated data.
  void reset() => _builder.reset();

  /// Appends [chunk], returning true and clearing data when the limit is
  /// exceeded.
  bool append(String chunk) {
    _builder.append(chunk);
    if (_builder.length > limit) {
      _builder.reset();
      return true;
    }
    return false;
  }

  @override
  String toString() => _builder.toString();
}
