/// Normalizes LF and CRLF line endings to terminal carriage returns.
String prepareTextForTerminal(String text) =>
    text.replaceAll(RegExp(r'\r?\n'), '\r');

/// Wraps [text] for bracketed paste and neutralizes embedded escape bytes.
String bracketTextForPaste(String text, {required bool bracketedPasteMode}) {
  if (!bracketedPasteMode) return text;
  final sanitized = text.replaceAll('\u001b', '\u241b');
  return '\u001b[200~$sanitized\u001b[201~';
}
