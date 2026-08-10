/// Character replacement map used by ISO-2022 G0-G3 designation.
typedef TerminalCharset = Map<int, int>;

/// Tracks designated and active terminal character sets.
final class CharsetService {
  TerminalCharset? _charset;
  int _gLevel = 0;
  List<TerminalCharset?> _charsets = <TerminalCharset?>[];

  /// Currently invoked charset, or `null` for the default charset.
  TerminalCharset? get charset => _charset;

  /// Currently invoked G-level.
  int get gLevel => _gLevel;

  /// Designated charsets indexed by G-level.
  List<TerminalCharset?> get charsets => _charsets;

  /// Restores G0 and removes every designation.
  void reset() {
    _charset = null;
    _charsets = <TerminalCharset?>[];
    _gLevel = 0;
  }

  /// Invokes the charset designated at [level].
  void setGLevel(int level) {
    _gLevel = level;
    _charset = level < _charsets.length ? _charsets[level] : null;
  }

  /// Designates [charset] at [level].
  void setGCharset(int level, TerminalCharset? charset) {
    while (_charsets.length <= level) {
      _charsets.add(null);
    }
    _charsets[level] = charset;
    if (_gLevel == level) _charset = charset;
  }
}
