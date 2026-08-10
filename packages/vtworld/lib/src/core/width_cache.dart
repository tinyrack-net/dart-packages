import 'package:vtworld/src/core/disposable.dart';

/// Canvas-independent font measurement surface used by [WidthCache].
abstract interface class WidthCacheCanvas {
  /// Selects the font used by subsequent [measure] calls.
  void setFont(
    String family,
    double size,
    Object weight, {
    required bool italic,
  });

  /// Measures [text] in logical pixels.
  double measure(String text);
}

/// xterm's two-tier glyph width cache.
final class WidthCache implements Disposable {
  /// Creates four independent regular/bold/italic measurement surfaces.
  WidthCache(WidthCacheCanvas Function() canvasFactory)
    : _canvases = List<WidthCacheCanvas>.generate(4, (_) => canvasFactory()) {
    clear();
  }

  /// Sentinel for an unset flat-cache entry.
  static const flatUnset = -9999.0;

  /// Number of UTF-16 code units served by the flat cache.
  static const flatSize = 256;

  /// Character repeat count used by xterm's measuring implementation.
  static const repeat = 32;

  final List<double> _flat = List<double>.filled(flatSize, flatUnset);
  Map<String, double>? _sparse;
  final List<WidthCacheCanvas> _canvases;
  String _font = '';
  double _fontSize = 0;
  Object _weight = 'normal';
  Object _weightBold = 'bold';
  bool _isDisposed = false;

  /// Read-only diagnostic view used by the upstream parity suite.
  List<double> get flatCache => List<double>.unmodifiable(_flat);

  /// Read-only diagnostic view used by the upstream parity suite.
  Map<String, double>? get sparseCache =>
      _sparse == null ? null : Map<String, double>.unmodifiable(_sparse!);

  /// Clears both cache tiers.
  void clear() {
    _flat.fillRange(0, _flat.length, flatUnset);
    _sparse = <String, double>{};
  }

  /// Updates all four font variants and invalidates changed settings.
  void setFont(String font, double fontSize, Object weight, Object weightBold) {
    if (font == _font &&
        fontSize == _fontSize &&
        weight == _weight &&
        weightBold == _weightBold) {
      return;
    }
    _font = font;
    _fontSize = fontSize;
    _weight = weight;
    _weightBold = weightBold;
    _canvases[0].setFont(font, fontSize, weight, italic: false);
    _canvases[1].setFont(font, fontSize, weightBold, italic: false);
    _canvases[2].setFont(font, fontSize, weight, italic: true);
    _canvases[3].setFont(font, fontSize, weightBold, italic: true);
    clear();
  }

  /// Returns the cached or freshly measured width for a font variant.
  double get(String text, Object bold, Object italic) {
    final isBold = _truthy(bold);
    final isItalic = _truthy(italic);
    if (!isBold && !isItalic && text.length == 1) {
      final codepoint = text.codeUnitAt(0);
      if (codepoint < flatSize) {
        final cached = _flat[codepoint];
        if (cached != flatUnset) return cached;
        final width = _measure(text, 0);
        if (width > 0) _flat[codepoint] = width;
        return width;
      }
    }
    var key = text;
    if (isBold) key += 'B';
    if (isItalic) key += 'I';
    final sparse = _sparse!;
    final cached = sparse[key];
    if (cached != null) return cached;
    var variant = 0;
    if (isBold) variant |= 1;
    if (isItalic) variant |= 2;
    final width = _measure(text, variant);
    if (width > 0) sparse[key] = width;
    return width;
  }

  double _measure(String text, int variant) => _canvases[variant].measure(text);

  static bool _truthy(Object value) => value != false && value != 0;

  @override
  bool get isDisposed => _isDisposed;

  /// Releases measurement surfaces and the sparse cache.
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _canvases.clear();
    _sparse = null;
  }
}
