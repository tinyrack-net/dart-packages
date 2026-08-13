import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vtworld/src/core/addon.dart';
import 'package:vtworld/src/core/addon_manager.dart';
import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/clipboard.dart';
import 'package:vtworld/src/core/color.dart';
import 'package:vtworld/src/core/decoration_service.dart';
import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';
import 'package:vtworld/src/core/kitty_keyboard.dart';
import 'package:vtworld/src/core/marker.dart';
import 'package:vtworld/src/core/mouse_state_service.dart';
import 'package:vtworld/src/core/options.dart';
import 'package:vtworld/src/core/parser.dart';
import 'package:vtworld/src/core/selection_model.dart';
import 'package:vtworld/src/core/text_decoder.dart';
import 'package:vtworld/src/core/unicode.dart';
import 'package:vtworld/src/core/version.dart';
import 'package:vtworld/src/core/windows_mode.dart';
import 'package:vtworld/src/core/write_buffer.dart';

part 'engine.dart';

bool _hasWriteSyncWarningHappened = false;

/// Terminal viewport size.
final class TerminalResizeEvent {
  /// xterm-compatible `TerminalResizeEvent` API.
  const TerminalResizeEvent({required this.cols, required this.rows});

  /// xterm-compatible `cols` API.
  final int cols;

  /// xterm-compatible `rows` API.
  final int rows;
}

/// Inclusive set of rows that were rendered.
final class TerminalRenderEvent {
  /// xterm-compatible `TerminalRenderEvent` API.
  const TerminalRenderEvent({required this.start, required this.end});

  /// xterm-compatible `start` API.
  final int start;

  /// xterm-compatible `end` API.
  final int end;
}

/// Renderer-facing snapshot of colors changed by OSC 4/10/11/12.
///
/// The values are packed 24-bit RGB integers. Missing values mean that the
/// corresponding color still comes from [TerminalOptions.theme].
final class TerminalColorOverrides {
  /// Creates an immutable dynamic color snapshot.
  TerminalColorOverrides({
    required Map<int, int> indexed,
    this.foreground,
    this.background,
    this.cursor,
  }) : indexed = Map<int, int>.unmodifiable(indexed);

  /// OSC 4 palette overrides keyed by an index in the range 0 through 255.
  final Map<int, int> indexed;

  /// OSC 10 default foreground override.
  final int? foreground;

  /// OSC 11 default background override.
  final int? background;

  /// OSC 12 cursor override.
  final int? cursor;
}

/// Width and height in logical or device pixels.
final class TerminalPixelDimensions {
  /// Creates immutable dimensions.
  const TerminalPixelDimensions({required this.width, required this.height});

  /// Horizontal extent.
  final double width;

  /// Vertical extent.
  final double height;
}

/// Top and left offset within a renderer cell.
final class TerminalPixelOffset {
  /// Creates an immutable renderer offset.
  const TerminalPixelOffset({required this.top, required this.left});

  /// Offset from the top of the cell.
  final double top;

  /// Offset from the left of the cell.
  final double left;
}

/// Character dimensions and its offset within a cell.
final class TerminalCharacterDimensions {
  /// Creates immutable character geometry.
  const TerminalCharacterDimensions({
    required this.width,
    required this.height,
    required this.top,
    required this.left,
  });

  /// Character width.
  final double width;

  /// Character height.
  final double height;

  /// Offset from the top of the cell.
  final double top;

  /// Offset from the left of the cell.
  final double left;
}

/// Canvas and cell dimensions in one coordinate space.
final class TerminalRenderDimensionSet {
  /// Creates a CSS-pixel dimension set.
  const TerminalRenderDimensionSet({required this.canvas, required this.cell});

  /// Full terminal canvas.
  final TerminalPixelDimensions canvas;

  /// One terminal cell.
  final TerminalPixelDimensions cell;
}

/// Canvas, cell and character dimensions in device pixels.
final class TerminalDeviceRenderDimensionSet {
  /// Creates a device-pixel dimension set.
  const TerminalDeviceRenderDimensionSet({
    required this.canvas,
    required this.cell,
    required this.char,
  });

  /// Full terminal canvas.
  final TerminalPixelDimensions canvas;

  /// One terminal cell.
  final TerminalPixelDimensions cell;

  /// Character box and offset inside a cell.
  final TerminalCharacterDimensions char;
}

/// Physical and logical renderer dimensions.
final class TerminalRenderDimensions {
  /// xterm-compatible `TerminalRenderDimensions` API.
  const TerminalRenderDimensions({
    required this.width,
    required this.height,
    required this.cellWidth,
    required this.cellHeight,
    required this.devicePixelRatio,
  });

  /// xterm-compatible `width` API.
  final double width;

  /// xterm-compatible `height` API.
  final double height;

  /// xterm-compatible `cellWidth` API.
  final double cellWidth;

  /// xterm-compatible `cellHeight` API.
  final double cellHeight;

  /// xterm-compatible `devicePixelRatio` API.
  final double devicePixelRatio;

  /// xterm-compatible CSS-pixel canvas and cell dimensions.
  TerminalRenderDimensionSet get css => TerminalRenderDimensionSet(
    canvas: TerminalPixelDimensions(width: width, height: height),
    cell: TerminalPixelDimensions(width: cellWidth, height: cellHeight),
  );

  /// xterm-compatible device-pixel canvas, cell and character dimensions.
  TerminalDeviceRenderDimensionSet get device {
    final ratio = devicePixelRatio;
    final deviceCell = TerminalPixelDimensions(
      width: cellWidth * ratio,
      height: cellHeight * ratio,
    );
    return TerminalDeviceRenderDimensionSet(
      canvas: TerminalPixelDimensions(
        width: width * ratio,
        height: height * ratio,
      ),
      cell: deviceCell,
      char: TerminalCharacterDimensions(
        width: deviceCell.width,
        height: deviceCell.height,
        top: 0,
        left: 0,
      ),
    );
  }
}

/// A renderer-independent keyboard event.
final class TerminalKeyEvent {
  /// xterm-compatible `TerminalKeyEvent` API.
  const TerminalKeyEvent({
    required this.key,
    this.shift = false,
    this.alt = false,
    this.control = false,
    this.meta = false,
  });

  /// xterm-compatible `key` API.
  final String key;

  /// xterm-compatible `shift` API.
  final bool shift;

  /// xterm-compatible `alt` API.
  final bool alt;

  /// xterm-compatible `control` API.
  final bool control;

  /// xterm-compatible `meta` API.
  final bool meta;
}

/// A renderer-independent wheel event.
final class TerminalWheelEvent {
  /// xterm-compatible `TerminalWheelEvent` API.
  const TerminalWheelEvent({
    required this.deltaX,
    required this.deltaY,
    this.shift = false,
    this.alt = false,
    this.control = false,
    this.meta = false,
  });

  /// xterm-compatible `deltaX` API.
  final double deltaX;

  /// xterm-compatible `deltaY` API.
  final double deltaY;

  /// xterm-compatible `shift` API.
  final bool shift;

  /// xterm-compatible `alt` API.
  final bool alt;

  /// xterm-compatible `control` API.
  final bool control;

  /// xterm-compatible `meta` API.
  final bool meta;
}

/// Mouse buttons understood by xterm's core mouse protocols.
enum TerminalMouseButton {
  /// Primary button.
  left,

  /// Middle button.
  middle,

  /// Secondary button.
  right,

  /// Motion without a pressed button.
  none,

  /// Wheel pseudo-button.
  wheel,
}

/// Mouse actions understood by xterm's core mouse protocols.
enum TerminalMouseAction {
  /// Button release or upward wheel motion.
  up,

  /// Button press or downward wheel motion.
  down,

  /// Leftward wheel motion.
  wheelLeft,

  /// Rightward wheel motion.
  wheelRight,

  /// Pointer motion.
  move,
}

/// Renderer-independent mouse event using zero-based cell coordinates.
final class TerminalMouseEvent {
  /// Creates a core mouse event.
  const TerminalMouseEvent({
    required this.column,
    required this.row,
    required this.button,
    required this.action,
    this.pixelX = 1,
    this.pixelY = 1,
    this.shift = false,
    this.alt = false,
    this.control = false,
  });

  /// Zero-based viewport column.
  final int column;

  /// Zero-based viewport row.
  final int row;

  /// One-based horizontal pixel position for SGR-pixels mode.
  final int pixelX;

  /// One-based vertical pixel position for SGR-pixels mode.
  final int pixelY;

  /// Reported button.
  final TerminalMouseButton button;

  /// Reported action.
  final TerminalMouseAction action;

  /// Shift modifier state.
  final bool shift;

  /// Alt modifier state.
  final bool alt;

  /// Control modifier state.
  final bool control;
}

/// Character join range, inclusive at [start] and exclusive at [end].
final class TerminalCharacterJoin {
  /// xterm-compatible `TerminalCharacterJoin` API.
  const TerminalCharacterJoin(this.start, this.end);

  /// xterm-compatible `start` API.
  final int start;

  /// xterm-compatible `end` API.
  final int end;
}

/// xterm-compatible `TerminalCharacterJoiner` API.
typedef TerminalCharacterJoiner = List<TerminalCharacterJoin> Function(
  String text,
);

/// Link returned by a terminal link provider.
final class TerminalLink {
  /// xterm-compatible `TerminalLink` API.
  TerminalLink({
    required this.range,
    required this.text,
    required this.activate,
    this.decorations,
    this.hover,
    this.leave,
    this.dispose,
  });

  /// xterm-compatible `range` API.
  final TerminalBufferRange range;

  /// xterm-compatible `text` API.
  final String text;

  /// xterm-compatible `Function` API.
  final void Function(Object? event, String text) activate;

  /// Optional renderer-managed pointer and underline state.
  TerminalLinkDecorations? decorations;

  /// Invoked when a pointer enters the link.
  final void Function(Object? event, String text)? hover;

  /// Invoked when a pointer leaves the link.
  final void Function(Object? event, String text)? leave;

  /// Releases provider-owned link resources.
  final void Function()? dispose;
}

/// Viewport-relative cell range used to show or hide a link underline.
final class TerminalLinkUnderlineEvent {
  /// Converts xterm's 1-based link range into renderer coordinates.
  TerminalLinkUnderlineEvent.fromLink(
    TerminalLink link, {
    required this.columns,
    int viewportY = 0,
    this.foreground,
  }) : x1 = link.range.start.x - 1,
       y1 = link.range.start.y - viewportY - 1,
       x2 = link.range.end.x,
       y2 = link.range.end.y - viewportY - 1;

  /// Inclusive zero-based starting column.
  final int x1;

  /// Inclusive viewport-relative starting row.
  final int y1;

  /// Exclusive ending column on the last row.
  final int x2;

  /// Inclusive viewport-relative ending row.
  final int y2;

  /// Terminal column count at the time the event was created.
  final int columns;

  /// Optional palette foreground supplied by a legacy matcher.
  final int? foreground;
}

/// Mutable visual state associated with a resolved link.
final class TerminalLinkDecorations {
  /// Creates link decoration state using xterm's enabled defaults.
  TerminalLinkDecorations({this._pointerCursor = true, this._underline = true});

  bool _pointerCursor;
  bool _underline;
  final List<void Function()> _listeners = <void Function()>[];

  /// Whether hovering requests a pointer cursor.
  bool get pointerCursor => _pointerCursor;
  set pointerCursor(bool value) {
    if (value == _pointerCursor) return;
    _pointerCursor = value;
    _notifyListeners();
  }

  /// Whether hovering underlines the link.
  bool get underline => _underline;
  set underline(bool value) {
    if (value == _underline) return;
    _underline = value;
    _notifyListeners();
  }

  /// Observes live decoration changes while a renderer owns the link.
  Disposable onChange(void Function() listener) {
    _listeners.add(listener);
    return CallbackDisposable(() => _listeners.remove(listener));
  }

  void _notifyListeners() {
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }
}

/// Resolves links for one 1-based buffer line.
// A named interface allows providers to retain lifecycle-specific state.
abstract interface class TerminalLinkProvider {
  /// xterm-compatible `provideLinks` API using a 1-based buffer line number.
  FutureOr<List<TerminalLink>> provideLinks(int bufferLineNumber);
}

/// Read-only mode state set by terminal escape sequences.
final class TerminalModes {
  TerminalModes._(this._terminal);

  final Terminal _terminal;

  /// xterm-compatible `applicationCursorKeysMode` API.
  bool get applicationCursorKeysMode => _terminal._engine.cursorKeysMode;

  /// xterm-compatible `applicationKeypadMode` API.
  bool get applicationKeypadMode => _terminal._engine.appKeypadMode;

  /// xterm-compatible `bracketedPasteMode` API.
  bool get bracketedPasteMode => _terminal._engine.bracketedPasteMode;

  /// Whether OSC color scheme update notifications are enabled.
  bool get colorSchemeUpdates => _terminal._engine.colorSchemeUpdates;

  /// Effective cursor style after a DECSCUSR override.
  TerminalCursorStyle get cursorStyle =>
      _terminal._engine.cursorStyleOverride ?? _terminal.options.cursorStyle;

  /// Effective cursor blinking after a DECSCUSR override.
  bool get cursorBlink =>
      _terminal._engine.cursorBlinkOverride ?? _terminal.options.cursorBlink;

  /// xterm-compatible `insertMode` API.
  bool get insertMode => _terminal._engine.insertMode;

  /// xterm-compatible `originMode` API.
  bool get originMode => _terminal._engine.originMode;

  /// xterm-compatible `sendFocusMode` API.
  bool get sendFocusMode => _terminal._engine.reportFocusMode;

  /// xterm-compatible `showCursor` API.
  bool get showCursor => _terminal._engine.cursorVisibleMode;

  /// xterm-compatible `wraparoundMode` API.
  bool get wraparoundMode => _terminal._engine.autoWrapMode;

  /// xterm-compatible `reverseWraparoundMode` API.
  bool get reverseWraparoundMode => _terminal._engine.reverseWraparoundMode;

  /// xterm-compatible `synchronizedOutputMode` API.
  bool get synchronizedOutputMode => _terminal._engine.synchronizedOutputMode;

  /// xterm-compatible `win32InputMode` API.
  bool get win32InputMode => _terminal._engine.win32InputMode;

  /// Zero-based top margin of the active DECSTBM scroll region.
  int get scrollTop => _terminal._engine.marginTop;

  /// Zero-based bottom margin of the active DECSTBM scroll region.
  int get scrollBottom => _terminal._engine.marginBottom;

  /// xterm-compatible `switch` API.
  String get mouseTrackingMode => switch (_terminal._engine.mouseMode) {
    TerminalMouseTrackingMode.none => 'none',
    TerminalMouseTrackingMode.x10 => 'x10',
    TerminalMouseTrackingMode.vt200 => 'vt200',
    TerminalMouseTrackingMode.drag => 'drag',
    TerminalMouseTrackingMode.any => 'any',
  };

  /// Active core mouse protocol used by xterm integration diagnostics.
  String get mouseProtocol => switch (_terminal._engine.mouseMode) {
    TerminalMouseTrackingMode.none => 'NONE',
    TerminalMouseTrackingMode.x10 => 'X10',
    TerminalMouseTrackingMode.vt200 => 'VT200',
    TerminalMouseTrackingMode.drag => 'DRAG',
    TerminalMouseTrackingMode.any => 'ANY',
  };

  /// Active core mouse encoding used by xterm integration diagnostics.
  String get mouseEncoding => _terminal._engine.sgrPixelsMouseMode
      ? 'SGR_PIXELS'
      : _terminal._engine.sgrMouseMode
      ? 'SGR'
      : 'DEFAULT';
}

/// Standalone terminal core ported from the pinned xterm.js behavior.
final class Terminal extends DisposableStore {
  /// Creates a terminal with xterm.js defaults.
  Terminal({TerminalOptions? options})
    : options = options ?? TerminalOptions() {
    _unicode = TerminalUnicodeHandling();
    _engine = _TerminalCoreEngine(
      options: this.options,
      unicode: _unicode,
      columns: this.options.cols < 2 ? 2 : this.options.cols,
      rows: this.options.rows < 1 ? 1 : this.options.rows,
      scrollback: this.options.scrollback,
      onBell: () {
        _onBell.fire(TerminalVoid.value);
      },
      onTitle: _onTitleChange.fire,
      onData: _triggerData,
      onRequestSendFocus: _reportCurrentFocus,
      onA11yChar: _onA11yChar.fire,
      onA11yTab: _onA11yTab.fire,
      onLineFeed: () => _onLineFeed.fire(TerminalVoid.value),
      onTrim: (amount) {
        if (_selectionModel.handleTrim(amount)) {
          _onSelectionChange.fire(TerminalVoid.value);
        }
      },
    );
    _synchronizedOutput = _SynchronizedOutputHandler(
      () => _engine.synchronizedOutputMode,
      () => _engine.synchronizedOutputMode = false,
      _onRender.fire,
    );
    buffer = _engine.buffer;
    _selectionModel = SelectionModel(
      columns: () => cols,
      rows: () => rows,
      bufferBaseY: () => buffer.active.baseY,
    );
    _decorationService = add(DecorationService(buffer));
    parser = add(
      TerminalParser((identifier, parameters) {
        if (identifier.prefix.isNotEmpty ||
            identifier.intermediates.isNotEmpty ||
            identifier.finalByte != 't') {
          return true;
        }
        final operation = parameters.isEmpty ? null : parameters.first;
        return operation is int && _engine._windowOptionAllowed(operation);
      }),
    );
    modes = TerminalModes._(this);
    _writeBuffer = add(WriteBuffer(_processWrite));
    add(
      _writeBuffer.onWriteParsed.listen(
        (_) => _onWriteParsed.fire(TerminalVoid.value),
      ),
    );
    _linkProviders.add(_OscLinkProvider(this));
    add(this.options.onChange.listen(_handleOptionChange));
  }

  /// Natural-language strings shared by all terminal instances.
  static TerminalLocalizableStrings strings =
      const TerminalLocalizableStrings();

  late _TerminalCoreEngine _engine;

  /// xterm-compatible `options` API.
  final TerminalOptions options;

  /// xterm-compatible `buffer` API.
  late final TerminalBufferNamespace buffer;

  /// xterm-compatible `parser` API.
  late final TerminalParser parser;

  /// xterm-compatible `unicode` API.
  TerminalUnicodeHandling get unicode {
    if (!options.allowProposedApi) {
      throw StateError(
        'You must set the allowProposedApi option to true to use proposed API',
      );
    }
    return _unicode;
  }

  late final TerminalUnicodeHandling _unicode;

  /// xterm-compatible `modes` API.
  late final TerminalModes modes;

  final TerminalEventEmitter<TerminalVoid> _onBell =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<String> _onBinary = TerminalEventEmitter<String>();
  final TerminalEventEmitter<TerminalVoid> _onCursorMove =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<String> _onData = TerminalEventEmitter<String>();
  final TerminalEventEmitter<TerminalKeyEvent> _onKey =
      TerminalEventEmitter<TerminalKeyEvent>();
  final TerminalEventEmitter<TerminalVoid> _onLineFeed =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<String> _onA11yChar =
      TerminalEventEmitter<String>();
  final TerminalEventEmitter<int> _onA11yTab = TerminalEventEmitter<int>();
  final TerminalEventEmitter<TerminalRenderEvent> _onRender =
      TerminalEventEmitter<TerminalRenderEvent>();
  final TerminalEventEmitter<TerminalVoid> _onWriteParsed =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalVoid> _onReset =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalResizeEvent> _onResize =
      TerminalEventEmitter<TerminalResizeEvent>();
  final TerminalEventEmitter<int> _onScroll = TerminalEventEmitter<int>();
  final TerminalEventEmitter<TerminalVoid> _onSelectionChange =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<String> _onTitleChange =
      TerminalEventEmitter<String>();
  final TerminalEventEmitter<TerminalRenderDimensions> _onDimensionsChange =
      TerminalEventEmitter<TerminalRenderDimensions>();

  /// xterm-compatible `onBell` API.
  TerminalEvent<TerminalVoid> get onBell => _onBell.event;

  /// xterm-compatible `onBinary` API.
  TerminalEvent<String> get onBinary => _onBinary.event;

  /// xterm-compatible `onCursorMove` API.
  TerminalEvent<TerminalVoid> get onCursorMove => _onCursorMove.event;

  /// xterm-compatible `onData` API.
  TerminalEvent<String> get onData => _onData.event;

  /// xterm-compatible `onKey` API.
  TerminalEvent<TerminalKeyEvent> get onKey => _onKey.event;

  /// xterm-compatible `onLineFeed` API.
  TerminalEvent<TerminalVoid> get onLineFeed => _onLineFeed.event;

  /// Characters emitted by the input handler for assistive technology.
  TerminalEvent<String> get onA11yChar => _onA11yChar.event;

  /// Spaces traversed by HT for assistive technology.
  TerminalEvent<int> get onA11yTab => _onA11yTab.event;

  /// xterm-compatible `onRender` API.
  TerminalEvent<TerminalRenderEvent> get onRender => _onRender.event;

  /// xterm-compatible `onWriteParsed` API.
  TerminalEvent<TerminalVoid> get onWriteParsed => _onWriteParsed.event;

  /// Fires synchronously after a full RIS or API reset.
  TerminalEvent<TerminalVoid> get onReset => _onReset.event;

  /// xterm-compatible `onResize` API.
  TerminalEvent<TerminalResizeEvent> get onResize => _onResize.event;

  /// xterm-compatible `onScroll` API.
  TerminalEvent<int> get onScroll => _onScroll.event;

  /// xterm-compatible `onSelectionChange` API.
  TerminalEvent<TerminalVoid> get onSelectionChange => _onSelectionChange.event;

  /// xterm-compatible `onTitleChange` API.
  TerminalEvent<String> get onTitleChange => _onTitleChange.event;

  /// xterm-compatible `onDimensionsChange` API.
  TerminalEvent<TerminalRenderDimensions> get onDimensionsChange =>
      _onDimensionsChange.event;

  /// xterm-compatible `rows` API.
  int get rows => _engine.rows;

  /// xterm-compatible `cols` API.
  int get cols => _engine.columns;

  /// Current input-handler attributes used for subsequently printed cells.
  TerminalCellAttributes get currentAttributes => _engine.currentAttributes;

  /// Effective renderer overrides installed by OSC color control sequences.
  TerminalColorOverrides get colorOverrides => _engine.colorOverrides;

  /// Active Kitty keyboard protocol enhancement flags.
  int get kittyKeyboardFlags => _engine.kittyKeyboardFlags;

  /// xterm-compatible `unmodifiable` API.
  List<TerminalMarker> get markers => buffer.active.markers;

  /// xterm-compatible `dimensions` API.
  TerminalRenderDimensions? get dimensions => _dimensions;

  /// Flutter element hosting this terminal, or null before a view is mounted.
  Object? get element => _element;

  /// Flutter render object hosting the terminal screen, when laid out.
  Object? get screenElement => _screenElement;

  /// Flutter text-input client accepting composed input, when attached.
  Object? get textarea => _textarea;

  late final WriteBuffer _writeBuffer;
  late final _SynchronizedOutputHandler _synchronizedOutput;
  final Utf8ToUtf32 _decoder = Utf8ToUtf32();
  final StringToUtf32 _stringDecoder = StringToUtf32();
  bool _writeContinuationPending = false;
  int _viewportY = 0;
  late final SelectionModel _selectionModel;
  bool _selectionColumnMode = false;
  TerminalRenderDimensions? _dimensions;
  late final DecorationService _decorationService;
  bool _isDisposing = false;
  final AddonManager _addonManager = AddonManager();
  final KittyKeyboard _kittyKeyboard = KittyKeyboard();
  final Win32InputMode _win32InputMode = Win32InputMode();
  final List<TerminalLinkProvider> _linkProviders = <TerminalLinkProvider>[];
  final Map<int, TerminalCharacterJoiner> _characterJoiners =
      <int, TerminalCharacterJoiner>{};
  int _nextCharacterJoinerId = 1;
  bool Function(TerminalKeyEvent event)? _customKeyHandler;
  bool Function(TerminalWheelEvent event)? _customWheelHandler;
  void Function()? _focus;
  void Function()? _blur;
  bool _hasFocus = false;
  Object? _element;
  Object? _screenElement;
  Object? _textarea;
  final MouseStateService _mouseStateService = MouseStateService();
  CoreMouseEvent? _lastMouseEvent;

  void _handleOptionChange(String name) {
    _engine.handleOptionChange(name);
    final nextViewport = _viewportY.clamp(0, buffer.normal.baseY);
    if (nextViewport != _viewportY) {
      _viewportY = nextViewport;
      _onScroll.fire(_viewportY);
    }
    buffer.active.displayY = _viewportY;
    _requestRender(0, rows - 1);
  }

  /// Queues text or UTF-8 bytes for ordered parsing.
  void write(Object data, {void Function()? onParsed}) {
    _checkData(data);
    if (isDisposed) throw StateError('Terminal has been disposed');
    _writeBuffer.write(data, onParsed);
  }

  /// Queues text followed by CRLF.
  void writeln(Object data, {void Function()? onParsed}) {
    _checkData(data);
    write(data);
    write('\r\n', onParsed: onParsed);
  }

  /// Queues data and completes after its parser callback fires.
  Future<void> writeAndWait(Object data) {
    _checkData(data);
    if (isDisposed) throw StateError('Terminal has been disposed');
    final completer = Completer<void>();
    _writeBuffer.write(data, completer.complete);
    return completer.future;
  }

  /// Immediately parses [data] with xterm's deprecated synchronous contract.
  void writeSync(Object data, [int? maxSubsequentCalls]) {
    _checkData(data);
    if (isDisposed) return;
    if (!_hasWriteSyncWarningHappened &&
        options.logLevel.index <= TerminalLogLevel.warning.index) {
      options.logger?.warn('writeSync is unreliable and will be removed soon.');
      _hasWriteSyncWarningHappened = true;
    }
    _writeBuffer.writeSync(data, maxSubsequentCalls);
  }

  static void _checkData(Object data) {
    if (data is! String && data is! Uint8List) {
      throw ArgumentError.value(data, 'data', 'must be String or Uint8List');
    }
  }

  Object? _processWrite(Object data, [bool? promiseResult]) {
    if (promiseResult != null && _writeContinuationPending) {
      _writeContinuationPending = false;
      return null;
    }
    final text = data is String
        ? _decodeString(data)
        : _decodeUtf8(data as Uint8List);
    final result = _parse(text);
    if (promiseResult != null) _writeContinuationPending = true;
    return result.then((_) => true);
  }

  String _decodeString(String input) {
    final target = Uint32List(input.length + 1);
    final length = _stringDecoder.decode(input, target);
    return utf32ToString(target, end: length);
  }

  String _decodeUtf8(Uint8List input) {
    final target = Uint32List(input.length + 1);
    final length = _decoder.decode(input, target);
    return utf32ToString(target, end: length);
  }

  Future<void> _parse(String text) async {
    final cursorX = buffer.active.cursorX;
    final cursorY = buffer.active.cursorY;
    final wasAtBottom = _viewportY == buffer.active.baseY;
    await parser.process(text, (filtered) {
      if (filtered.isNotEmpty) _engine.write(filtered);
    });
    final oldViewport = _viewportY;
    _viewportY = wasAtBottom
        ? buffer.active.baseY
        : _viewportY.clamp(0, buffer.active.baseY);
    buffer.active.displayY = _viewportY;
    if (_viewportY != oldViewport) _onScroll.fire(_viewportY);
    if (buffer.active.cursorX != cursorX || buffer.active.cursorY != cursorY) {
      _onCursorMove.fire(TerminalVoid.value);
    }
    final nextCursorY = buffer.active.cursorY;
    _requestRender(
      cursorY < nextCursorY ? cursorY : nextCursorY,
      cursorY > nextCursorY ? cursorY : nextCursorY,
    );
  }

  /// Sends application-side input exactly as typed input would.
  void input(String data, {bool wasUserInput = true}) {
    if (options.disableStdin || isDisposed) return;
    if (wasUserInput) _writeBuffer.handleUserInput();
    if (wasUserInput && options.scrollOnUserInput) scrollToBottom();
    _triggerData(data);
  }

  /// Normalizes, sanitizes, and optionally brackets pasted text.
  void paste(String data) {
    final prepared = bracketTextForPaste(
      prepareTextForTerminal(data),
      bracketedPasteMode:
          _engine.bracketedPasteMode && !options.ignoreBracketedPasteMode,
    );
    input(prepared);
  }

  void _triggerData(String data) {
    if (options.disableStdin || isDisposed) return;
    _onData.fire(data);
  }

  /// Resizes both normal and alternate buffers.
  void resize(int columns, int rowCount) {
    _writeBuffer.flushSync();
    if (columns == cols && rowCount == rows) return;
    final nextColumns = columns < 2 ? 2 : columns;
    final nextRows = rowCount < 1 ? 1 : rowCount;
    _engine.resize(nextColumns, nextRows);
    _onResize.fire(TerminalResizeEvent(cols: nextColumns, rows: nextRows));
    _viewportY = _viewportY.clamp(0, buffer.active.baseY);
    buffer.active.displayY = _viewportY;
  }

  /// xterm-compatible `focus` API.
  void focus() => _focus?.call();

  /// xterm-compatible `blur` API.
  void blur() => _blur?.call();

  /// Installs focus callbacks for the active Flutter view.
  void attachFocusHandlers({void Function()? focus, void Function()? blur}) {
    _focus = focus;
    _blur = blur;
  }

  /// Attaches Flutter equivalents of xterm's element, screen and textarea.
  void attachViewElements({Object? element, Object? screen, Object? textarea}) {
    _element = element;
    _screenElement = screen;
    _textarea = textarea;
  }

  /// Reports a renderer focus transition to the terminal input service.
  ///
  /// Renderer adapters call this after their native focus state has actually
  /// changed. When DECSET 1004 is active this emits the same focus-in or
  /// focus-out sequence as xterm.js' textarea boundary.
  void reportFocus({required bool focused}) {
    if (_hasFocus == focused) return;
    _hasFocus = focused;
    if (_engine.reportFocusMode) _reportCurrentFocus();
  }

  /// Current focus snapshot consumed by renderer addons.
  bool get rendererHasFocus => _hasFocus;

  void _reportCurrentFocus() =>
      _triggerData(_hasFocus ? '\u001b[I' : '\u001b[O');

  /// xterm-compatible `attachCustomKeyEventHandler` API.
  // This method name is fixed by xterm's public API.
  // ignore: use_setters_to_change_properties
  void attachCustomKeyEventHandler(
    bool Function(TerminalKeyEvent event) handler,
  ) {
    _customKeyHandler = handler;
  }

  /// xterm-compatible `attachCustomWheelEventHandler` API.
  // This method name is fixed by xterm's public API.
  // ignore: use_setters_to_change_properties
  void attachCustomWheelEventHandler(
    bool Function(TerminalWheelEvent event) handler,
  ) {
    _customWheelHandler = handler;
  }

  /// xterm-compatible `handleKeyEvent` API.
  bool handleKeyEvent(TerminalKeyEvent event) {
    _onKey.fire(event);
    return _customKeyHandler?.call(event) ?? true;
  }

  /// Encodes one native keyboard event with the active Kitty protocol state.
  KittyKeyboardResult evaluateKittyKeyboard(
    KittyKeyboardEvent event, {
    KittyKeyboardEventType eventType = KittyKeyboardEventType.press,
  }) => _kittyKeyboard.evaluate(
    event,
    kittyKeyboardFlags,
    eventType: eventType,
    macOptionAsAlt: options.macOptionIsMeta,
  );

  /// Encodes one native keyboard event with DECSET 9001 Win32 input mode.
  KittyKeyboardResult evaluateWin32Keyboard(
    KittyKeyboardEvent event, {
    required bool isKeyDown,
  }) => _win32InputMode.evaluateKeyboardEvent(event, isKeyDown: isKeyDown);

  /// xterm-compatible `handleWheelEvent` API.
  bool handleWheelEvent(TerminalWheelEvent event) =>
      _customWheelHandler?.call(event) ?? true;

  /// Encodes and emits a mouse event according to the active DEC modes.
  bool reportMouseEvent(TerminalMouseEvent event) {
    final engine = _engine;
    if (engine.mouseMode == TerminalMouseTrackingMode.none ||
        event.column < 0 ||
        event.column >= cols ||
        event.row < 0 ||
        event.row >= rows) {
      return false;
    }
    if (event.button == TerminalMouseButton.wheel &&
            event.action == TerminalMouseAction.move ||
        event.button == TerminalMouseButton.none &&
            event.action != TerminalMouseAction.move ||
        event.button != TerminalMouseButton.wheel &&
            (event.action == TerminalMouseAction.wheelLeft ||
                event.action == TerminalMouseAction.wheelRight)) {
      return false;
    }
    final protocol = switch (engine.mouseMode) {
      TerminalMouseTrackingMode.none => 'NONE',
      TerminalMouseTrackingMode.x10 => 'X10',
      TerminalMouseTrackingMode.vt200 => 'VT200',
      TerminalMouseTrackingMode.drag => 'DRAG',
      TerminalMouseTrackingMode.any => 'ANY',
    };
    final encoding = engine.sgrPixelsMouseMode
        ? 'SGR_PIXELS'
        : engine.sgrMouseMode
        ? 'SGR'
        : 'DEFAULT';
    if (_mouseStateService.activeProtocol != protocol) {
      _mouseStateService.activeProtocol = protocol;
    }
    if (_mouseStateService.activeEncoding != encoding) {
      _mouseStateService.activeEncoding = encoding;
    }
    final coreEvent = CoreMouseEvent(
      column: event.column + 1,
      row: event.row + 1,
      x: event.pixelX,
      y: event.pixelY,
      button: switch (event.button) {
        TerminalMouseButton.left => CoreMouseButton.left,
        TerminalMouseButton.middle => CoreMouseButton.middle,
        TerminalMouseButton.right => CoreMouseButton.right,
        TerminalMouseButton.none => CoreMouseButton.none,
        TerminalMouseButton.wheel => CoreMouseButton.wheel,
      },
      action: switch (event.action) {
        TerminalMouseAction.up => CoreMouseAction.up,
        TerminalMouseAction.down => CoreMouseAction.down,
        TerminalMouseAction.wheelLeft => CoreMouseAction.left,
        TerminalMouseAction.wheelRight => CoreMouseAction.right,
        TerminalMouseAction.move => CoreMouseAction.move,
      },
      shift: event.shift,
      alt: event.alt,
      control: event.control,
    );
    if (coreEvent.button != CoreMouseButton.wheel &&
        options.mouseEventsRequireAlt) {
      if (!coreEvent.alt) return false;
      coreEvent.alt = false;
    }
    if (coreEvent.action == CoreMouseAction.move &&
        _mouseEventsEqual(
          _lastMouseEvent,
          coreEvent,
          pixels: _mouseStateService.isPixelEncoding,
        )) {
      return false;
    }
    if (!_mouseStateService.restrictMouseEvent(coreEvent)) return false;
    final report = _mouseStateService.encodeMouseEvent(coreEvent);
    if (report.isNotEmpty && _mouseStateService.isDefaultEncoding) {
      _onBinary.fire(report);
    } else if (report.isNotEmpty) {
      _triggerData(report);
    }
    _lastMouseEvent = coreEvent;
    return true;
  }

  bool _mouseEventsEqual(
    CoreMouseEvent? left,
    CoreMouseEvent right, {
    required bool pixels,
  }) {
    if (left == null) return false;
    if (pixels) {
      if (left.x != right.x || left.y != right.y) return false;
    } else if (left.column != right.column || left.row != right.row) {
      return false;
    }
    return left.button == right.button &&
        left.action == right.action &&
        left.control == right.control &&
        left.alt == right.alt &&
        left.shift == right.shift;
  }

  /// xterm-compatible `registerLinkProvider` API.
  Disposable registerLinkProvider(TerminalLinkProvider provider) {
    _linkProviders.add(provider);
    return CallbackDisposable(() => _linkProviders.remove(provider));
  }

  /// xterm-compatible `linkProviders` API.
  List<TerminalLinkProvider> get linkProviders =>
      List<TerminalLinkProvider>.unmodifiable(_linkProviders);

  /// xterm-compatible `registerCharacterJoiner` API.
  int registerCharacterJoiner(TerminalCharacterJoiner handler) {
    final id = _nextCharacterJoinerId++;
    _characterJoiners[id] = handler;
    return id;
  }

  /// xterm-compatible `deregisterCharacterJoiner` API.
  void deregisterCharacterJoiner(int joinerId) {
    if (_characterJoiners.remove(joinerId) == null) {
      throw ArgumentError.value(joinerId, 'joinerId', 'is not registered');
    }
  }

  /// xterm-compatible `characterJoins` API.
  List<TerminalCharacterJoin> characterJoins(String text) {
    final joins = <TerminalCharacterJoin>[
      for (final joiner in _characterJoiners.values) ...joiner(text),
    ]..sort((left, right) => left.start.compareTo(right.start));
    if (joins.length < 2) return joins;
    final merged = <TerminalCharacterJoin>[];
    for (final join in joins) {
      if (join.start < 0 || join.end <= join.start || join.end > text.length) {
        throw RangeError('Character join is outside the input text');
      }
      if (merged.isEmpty || join.start > merged.last.end) {
        merged.add(join);
      } else {
        final previous = merged.removeLast();
        merged.add(
          TerminalCharacterJoin(
            previous.start,
            previous.end > join.end ? previous.end : join.end,
          ),
        );
      }
    }
    return merged;
  }

  /// xterm-compatible `registerMarker` API.
  TerminalMarker? registerMarker({int cursorYOffset = 0}) {
    final active = buffer.active;
    final y = active.absoluteCursorY + cursorYOffset;
    return active.addMarker(y);
  }

  /// xterm-compatible `registerDecoration` API.
  TerminalDecoration? registerDecoration({
    required TerminalMarker marker,
    TerminalDecorationAnchor anchor = TerminalDecorationAnchor.left,
    int x = 0,
    int width = 1,
    int height = 1,
    String? backgroundColor,
    String? foregroundColor,
    String? borderColor,
    String? overviewRulerColor,
    TerminalOverviewRulerPosition overviewRulerPosition =
        TerminalOverviewRulerPosition.full,
    TerminalDecorationLayer layer = TerminalDecorationLayer.bottom,
  }) {
    if (marker.isDisposed || marker.line < 0) return null;
    final decoration = TerminalDecoration(
      marker: marker,
      anchor: anchor,
      x: x,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      overviewRulerColor: overviewRulerColor,
      overviewRulerPosition: overviewRulerPosition,
      layer: layer,
    );
    _decorationService.registerDecoration(decoration);
    decoration.onDispose.listen((_) {
      if (!_isDisposing) refresh(0, rows - 1);
    });
    refresh(0, rows - 1);
    return decoration;
  }

  /// xterm-compatible `decorations` API.
  List<TerminalDecoration> get decorations =>
      List<TerminalDecoration>.unmodifiable(_decorationService.decorations);

  /// xterm-compatible `hasSelection` API.
  bool hasSelection() {
    final selection = _selectionRange;
    return selection != null && selection.start != selection.end;
  }

  /// xterm-compatible `getSelection` API.
  String getSelection() {
    final selection = _selectionRange;
    if (selection == null || selection.start == selection.end) return '';
    if (_selectionColumnMode) {
      if (selection.start.x == selection.end.x) return '';
      final startColumn = math.min(selection.start.x, selection.end.x);
      final endColumn = math.max(selection.start.x, selection.end.x);
      final output = <String>[];
      for (var y = selection.start.y; y <= selection.end.y; y++) {
        final line = buffer.active.getLine(y);
        if (line == null) continue;
        output.add(
          line.translateToString(
            trimRight: true,
            startColumn: startColumn,
            endColumn: endColumn,
          ),
        );
      }
      return output.join('\n');
    }
    final output = StringBuffer();
    for (var y = selection.start.y; y <= selection.end.y; y++) {
      final line = buffer.active.getLine(y);
      if (line == null) continue;
      final start = y == selection.start.y ? selection.start.x : 0;
      final end = y == selection.end.y ? selection.end.x : line.length;
      output.write(
        line.translateToString(
          trimRight: true,
          startColumn: start,
          endColumn: end,
        ),
      );
      if (y != selection.end.y &&
          !(buffer.active.getLine(y + 1)?.isWrapped ?? false)) {
        output.write('\n');
      }
    }
    return output.toString();
  }

  /// xterm-compatible `getSelectionPosition` API.
  TerminalBufferRange? getSelectionPosition() =>
      hasSelection() ? _selectionRange : null;

  TerminalBufferRange? get _selectionRange {
    final start = _selectionModel.finalSelectionStart;
    final end = _selectionModel.finalSelectionEnd;
    if (start == null || end == null) return null;
    return TerminalBufferRange(start: start, end: end);
  }

  /// Whether the active pointer selection is rectangular.
  bool get selectionColumnMode => _selectionColumnMode;

  /// xterm-compatible `clearSelection` API.
  void clearSelection() {
    if (_selectionModel.finalSelectionStart == null) return;
    _selectionModel.clearSelection();
    _selectionColumnMode = false;
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// xterm-compatible `select` API.
  void select(int column, int row, int length) {
    _selectionModel
      ..clearSelection()
      ..selectionStart = TerminalBufferPosition(column, row)
      ..selectionStartLength = length;
    _selectionColumnMode = false;
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// Selects a rectangular region using xterm's column-selection semantics.
  void selectColumns(int startColumn, int startRow, int endColumn, int endRow) {
    final reversed = startRow > endRow;
    _selectionModel
      ..clearSelection()
      ..selectionStart = reversed
          ? TerminalBufferPosition(endColumn, endRow)
          : TerminalBufferPosition(startColumn, startRow)
      ..selectionEnd = reversed
          ? TerminalBufferPosition(startColumn, startRow)
          : TerminalBufferPosition(endColumn, endRow);
    _selectionColumnMode = true;
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// xterm-compatible `selectAll` API.
  void selectAll() {
    _selectionModel
      ..clearSelection()
      ..isSelectAllActive = true;
    _selectionColumnMode = false;
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// xterm-compatible `selectLines` API.
  void selectLines(int start, int end) {
    final startRow = start < 0 ? 0 : start;
    final lastLine = buffer.active.length - 1;
    final endRow = end > lastLine ? lastLine : end;
    final reversed = startRow > endRow;
    _selectionModel
      ..clearSelection()
      ..selectionStart = reversed
          ? TerminalBufferPosition(cols, endRow)
          : TerminalBufferPosition(0, startRow)
      ..selectionEnd = reversed
          ? TerminalBufferPosition(0, startRow)
          : TerminalBufferPosition(cols, endRow);
    _selectionColumnMode = false;
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// xterm-compatible `scrollLines` API.
  void scrollLines(int amount) => scrollToLine(_viewportY + amount);

  /// xterm-compatible `scrollPages` API.
  void scrollPages(int pageCount) => scrollLines(pageCount * (rows - 1));

  /// xterm-compatible `scrollToTop` API.
  void scrollToTop() => scrollToLine(0);

  /// xterm-compatible `scrollToBottom` API.
  void scrollToBottom() => scrollToLine(buffer.active.baseY);

  /// xterm-compatible `scrollToLine` API.
  void scrollToLine(int line) {
    final next = line.clamp(0, buffer.active.baseY);
    if (next == _viewportY) return;
    _viewportY = next;
    buffer.active.displayY = next;
    _onScroll.fire(next);
  }

  /// xterm-compatible `viewportY` API.
  int get viewportY => _viewportY;

  /// Clears scrollback while preserving the current prompt line.
  void clear() {
    buffer.active
      ..clearAllMarkers()
      ..clearKeepingCursorLine();
    _viewportY = 0;
    buffer.active.displayY = 0;
    _onScroll.fire(0);
    refresh(0, rows - 1);
  }

  /// xterm-compatible `refresh` API.
  void refresh(int start, int end) {
    if (start < 0 || end < start || end >= rows) {
      throw RangeError('Refresh range must be within the viewport');
    }
    _requestRender(start, end);
  }

  void _requestRender(int start, int end) {
    _synchronizedOutput.refreshRows(start, end);
  }

  /// xterm-compatible `clearTextureAtlas` API.
  void clearTextureAtlas() => refresh(0, rows - 1);

  /// Performs a full RIS reset.
  void reset() {
    _engine.reset();
    _mouseStateService.reset();
    _lastMouseEvent = null;
    _viewportY = 0;
    buffer.active.displayY = 0;
    clearSelection();
    _onReset.fire(TerminalVoid.value);
    refresh(0, rows - 1);
  }

  /// xterm-compatible `loadAddon` API.
  void loadAddon(TerminalAddon addon) => _addonManager.loadAddon(this, addon);

  /// Called by the Flutter view after measuring its render surface.
  void updateDimensions(TerminalRenderDimensions value) {
    final previous = _dimensions;
    if (previous != null &&
        previous.width == value.width &&
        previous.height == value.height &&
        previous.cellWidth == value.cellWidth &&
        previous.cellHeight == value.cellHeight &&
        previous.devicePixelRatio == value.devicePixelRatio) {
      return;
    }
    _dimensions = value;
    _engine.renderDimensions = value;
    _onDimensionsChange.fire(value);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _isDisposing = true;
    _synchronizedOutput.dispose();
    _addonManager.dispose();
    _mouseStateService.dispose();
    _unicode.dispose();
    buffer.dispose();
    for (final emitter in <Disposable>[
      _onBell,
      _onBinary,
      _onCursorMove,
      _onData,
      _onKey,
      _onLineFeed,
      _onA11yChar,
      _onA11yTab,
      _onRender,
      _onWriteParsed,
      _onReset,
      _onResize,
      _onScroll,
      _onSelectionChange,
      _onTitleChange,
      _onDimensionsChange,
    ]) {
      emitter.dispose();
    }
    super.dispose();
  }
}

/// Buffers renderer refreshes while DEC private mode 2026 is active.
///
/// This mirrors xterm's browser `SynchronizedOutputHandler`: the first dirty
/// range starts a one-second safety timer, subsequent ranges are merged, and
/// either ESU or the timer flushes the complete range exactly once.
final class _SynchronizedOutputHandler {
  _SynchronizedOutputHandler(this._isEnabled, this._disable, this._render);

  static const Duration _timeoutDuration = Duration(milliseconds: 1000);

  final bool Function() _isEnabled;
  final void Function() _disable;
  final void Function(TerminalRenderEvent event) _render;
  Timer? _timeout;
  int _start = 0;
  int _end = 0;
  bool _isBuffering = false;
  bool _isDisposed = false;

  void refreshRows(int start, int end) {
    if (_isDisposed) return;
    if (_isEnabled()) {
      _bufferRows(start, end);
      return;
    }

    final nextStart = _isBuffering ? math.min(start, _start) : start;
    final nextEnd = _isBuffering ? math.max(end, _end) : end;
    if (_isBuffering) _flush();
    _render(TerminalRenderEvent(start: nextStart, end: nextEnd));
  }

  void _bufferRows(int start, int end) {
    if (_isBuffering) {
      _start = math.min(_start, start);
      _end = math.max(_end, end);
    } else {
      _start = start;
      _end = end;
      _isBuffering = true;
    }
    _timeout ??= Timer(_timeoutDuration, _handleTimeout);
  }

  void _handleTimeout() {
    _timeout = null;
    if (_isDisposed || !_isBuffering) return;
    _disable();
    final event = TerminalRenderEvent(start: _start, end: _end);
    _isBuffering = false;
    _render(event);
  }

  void _flush() {
    _timeout?.cancel();
    _timeout = null;
    _isBuffering = false;
  }

  void dispose() {
    _isDisposed = true;
    _flush();
  }
}

final class _OscLinkProvider implements TerminalLinkProvider {
  const _OscLinkProvider(this.terminal);

  final Terminal terminal;

  @override
  List<TerminalLink> provideLinks(int bufferLineNumber) {
    final line = terminal.buffer.active.getLine(bufferLineNumber - 1);
    if (line == null) return const <TerminalLink>[];
    final result = <TerminalLink>[];
    final lineLength = _trimmedLength(line);
    var currentLinkId = 0;
    var currentStart = -1;
    for (var x = 0; x <= lineLength; x++) {
      final linkId = x < lineLength ? line.getCell(x)?.hyperlinkId ?? 0 : 0;
      if (currentStart < 0 && linkId != 0) {
        currentStart = x;
        currentLinkId = linkId;
        continue;
      }
      if (currentStart < 0 || linkId == currentLinkId) continue;
      final data = terminal._engine.hyperlinkData(currentLinkId);
      if (data != null && _protocolAllowed(data.uri)) {
        final range = _wrappedRange(
          bufferLineNumber,
          currentStart,
          x,
          currentLinkId,
        );
        final handler = terminal.options.linkHandler;
        result.add(
          TerminalLink(
            range: range,
            text: data.uri,
            activate: (event, text) {
              handler?.activate(event, text, range);
            },
            hover: handler?.hover == null
                ? null
                : (event, text) => handler!.hover!(event, text, range),
            leave: handler?.leave == null
                ? null
                : (event, text) => handler!.leave!(event, text, range),
          ),
        );
      }
      if (linkId == 0) {
        currentStart = -1;
        currentLinkId = 0;
      } else {
        currentStart = x;
        currentLinkId = linkId;
      }
    }
    return result;
  }

  bool _protocolAllowed(String uri) {
    if (terminal.options.linkHandler?.allowNonHttpProtocols ?? false) {
      return true;
    }
    final schemeEnd = uri.indexOf(':');
    if (schemeEnd <= 0) return false;
    final scheme = uri.substring(0, schemeEnd).toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  TerminalBufferRange _wrappedRange(int y, int startX, int endX, int linkId) {
    final buffer = terminal.buffer.active;
    var startY = y;
    var finalStartX = startX;
    var endY = y;
    var finalEndX = endX;
    while (finalStartX == 0) {
      final current = buffer.getLine(startY - 1);
      final previous = buffer.getLine(startY - 2);
      if (current?.isWrapped != true || previous == null) break;
      final previousLength = _trimmedLength(previous);
      if (previousLength == 0 ||
          previous.getCell(previousLength - 1)?.hyperlinkId != linkId) {
        break;
      }
      var previousStart = previousLength - 1;
      while (previousStart > 0 &&
          previous.getCell(previousStart - 1)?.hyperlinkId == linkId) {
        previousStart--;
      }
      startY--;
      finalStartX = previousStart;
    }
    while (true) {
      final current = buffer.getLine(endY - 1);
      if (current == null || finalEndX != _trimmedLength(current)) break;
      final next = buffer.getLine(endY);
      if (next?.isWrapped != true || next == null) break;
      final nextLength = _trimmedLength(next);
      if (nextLength == 0 || next.getCell(0)?.hyperlinkId != linkId) break;
      var nextEnd = 1;
      while (nextEnd < nextLength &&
          next.getCell(nextEnd)?.hyperlinkId == linkId) {
        nextEnd++;
      }
      endY++;
      finalEndX = nextEnd;
    }
    return TerminalBufferRange(
      start: TerminalBufferPosition(finalStartX + 1, startY),
      end: TerminalBufferPosition(finalEndX, endY),
    );
  }

  int _trimmedLength(TerminalBufferLine line) {
    var result = line.length;
    while (result > 0) {
      final cell = line.getCell(result - 1);
      if (cell != null && (cell.chars.isNotEmpty || cell.hyperlinkId != 0)) {
        break;
      }
      result--;
    }
    return result;
  }
}
