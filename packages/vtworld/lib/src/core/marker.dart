import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';

/// A tracked location in the normal buffer.
final class TerminalMarker implements Disposable {
  TerminalMarker._(this._line) : id = _nextId++;

  static int _nextId = 1;

  /// xterm-compatible `id` API.
  final int id;
  int _line;
  final TerminalEventEmitter<TerminalVoid> _onDispose =
      TerminalEventEmitter<TerminalVoid>();
  final List<Disposable> _disposables = <Disposable>[];
  bool _isDisposed = false;

  /// xterm-compatible `line` API.
  int get line => _isDisposed ? -1 : _line;

  /// xterm-compatible `onDispose` API.
  TerminalEvent<TerminalVoid> get onDispose => _onDispose.event;

  @override
  bool get isDisposed => _isDisposed;

  /// Owns [disposable] for the rest of this marker's lifetime.
  T register<T extends Disposable>(T disposable) {
    _disposables.add(disposable);
    return disposable;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _line = -1;
    _onDispose.fire(TerminalVoid.value);
    for (final disposable in List<Disposable>.of(_disposables)) {
      disposable.dispose();
    }
    _disposables.clear();
    _onDispose.dispose();
  }

  /// Moves this marker when buffer lines are inserted or removed.
  void move(int amount) {
    if (_isDisposed) return;
    _line += amount;
    if (_line < 0) dispose();
  }
}

/// Decoration anchoring edge.
/// xterm-compatible `TerminalDecorationAnchor` API.
enum TerminalDecorationAnchor {
  /// Anchor to the marker's left edge.
  left,

  /// Anchor to the marker's right edge.
  right,
}

/// Decoration paint layer.
/// xterm-compatible `TerminalDecorationLayer` API.
enum TerminalDecorationLayer {
  /// Paint below terminal text.
  bottom,

  /// Paint above terminal text.
  top,
}

/// Horizontal lane used by an overview-ruler decoration.
enum TerminalOverviewRulerPosition {
  /// Fill the complete ruler width.
  full,

  /// Use the left lane.
  left,

  /// Use the center lane.
  center,

  /// Use the right lane.
  right,
}

/// Mutable overview-ruler state exposed by a rendered decoration.
final class TerminalDecorationRenderOptions {
  /// Creates mutable decoration render options.
  TerminalDecorationRenderOptions({required this.position, this.color});

  /// Overview-ruler color, or null when no marker is rendered there.
  String? color;

  /// Horizontal overview-ruler lane.
  TerminalOverviewRulerPosition position;
}

/// A marker-backed decoration.
final class TerminalDecoration implements Disposable {
  /// xterm-compatible `TerminalDecoration` API.
  TerminalDecoration({
    required this.marker,
    this.anchor = TerminalDecorationAnchor.left,
    this.x = 0,
    this.width = 1,
    this.height = 1,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    String? overviewRulerColor,
    TerminalOverviewRulerPosition overviewRulerPosition =
        TerminalOverviewRulerPosition.full,
    this.layer = TerminalDecorationLayer.bottom,
  }) : options = TerminalDecorationRenderOptions(
         color: overviewRulerColor,
         position: overviewRulerPosition,
       ) {
    if (x < 0) throw ArgumentError.value(x, 'x', 'cannot be negative');
    if (width < 0 || height < 0) {
      throw ArgumentError('width and height cannot be negative');
    }
  }

  /// xterm-compatible `marker` API.
  final TerminalMarker marker;

  /// xterm-compatible `anchor` API.
  final TerminalDecorationAnchor anchor;

  /// xterm-compatible `x` API.
  final int x;

  /// xterm-compatible `width` API.
  final int width;

  /// xterm-compatible `height` API.
  final int height;

  /// xterm-compatible `backgroundColor` API.
  final String? backgroundColor;

  /// xterm-compatible `foregroundColor` API.
  final String? foregroundColor;

  /// Optional outline color used by search and link decorations.
  final String? borderColor;

  /// Optional color presented in an overview ruler by capable renderers.
  String? get overviewRulerColor => options.color;

  /// Horizontal lane occupied in the overview ruler.
  TerminalOverviewRulerPosition get overviewRulerPosition => options.position;

  /// Mutable overview-ruler options, matching xterm's decoration contract.
  final TerminalDecorationRenderOptions options;

  /// Flutter render element after the first render, otherwise null.
  TerminalDecoration? get element => _element;
  TerminalDecoration? _element;

  /// xterm-compatible `layer` API.
  final TerminalDecorationLayer layer;
  final TerminalEventEmitter<TerminalDecoration> _onRender =
      TerminalEventEmitter<TerminalDecoration>();
  final TerminalEventEmitter<TerminalVoid> _onDispose =
      TerminalEventEmitter<TerminalVoid>();
  bool _isDisposed = false;

  /// xterm-compatible `onRender` API.
  TerminalEvent<TerminalDecoration> get onRender => _onRender.event;

  /// xterm-compatible `onDispose` API.
  TerminalEvent<TerminalVoid> get onDispose => _onDispose.event;

  /// xterm-compatible `rendered` API.
  void rendered() {
    if (!_isDisposed) {
      _element = this;
      _onRender.fire(this);
    }
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _element = null;
    _onDispose.fire(TerminalVoid.value);
    _onRender.dispose();
    _onDispose.dispose();
  }
}

/// Creates markers while keeping their identifiers monotonic per terminal.
final class TerminalMarkerFactory {
  /// xterm-compatible `create` API.
  TerminalMarker create(int line) => TerminalMarker._(line);
}
