import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';
import 'package:vtworld/src/core/platform_defaults.dart';

/// Terminal log levels in increasing severity order.
/// xterm-compatible `TerminalLogLevel` API.
enum TerminalLogLevel {
  /// Finest-grained internal tracing.
  trace,

  /// Debug diagnostics.
  debug,

  /// Informational diagnostics.
  info,

  /// Recoverable warning diagnostics.
  warning,

  /// Error diagnostics.
  error,

  /// Disables logging.
  off,
}

/// Cursor shape.
/// xterm-compatible `TerminalCursorStyle` API.
enum TerminalCursorStyle {
  /// A full-cell block cursor.
  block,

  /// An underline cursor.
  underline,

  /// A vertical bar cursor.
  bar,
}

/// Cursor shape used while the terminal is not focused.
/// xterm-compatible `TerminalInactiveCursorStyle` API.
enum TerminalInactiveCursorStyle {
  /// An outlined block cursor.
  outline,

  /// A full-cell block cursor.
  block,

  /// A vertical bar cursor.
  bar,

  /// An underline cursor.
  underline,

  /// No inactive cursor.
  none,
}

/// Logger used by the terminal core.
abstract interface class TerminalLogger {
  /// Emits a trace diagnostic.
  void trace(String message, [List<Object?> arguments = const <Object?>[]]);

  /// Emits a debug diagnostic.
  void debug(String message, [List<Object?> arguments = const <Object?>[]]);

  /// Emits an informational diagnostic.
  void info(String message, [List<Object?> arguments = const <Object?>[]]);

  /// Emits a warning diagnostic.
  void warn(String message, [List<Object?> arguments = const <Object?>[]]);

  /// Emits an error diagnostic.
  void error(Object message, [List<Object?> arguments = const <Object?>[]]);
}

/// Callbacks for links emitted by OSC 8 or custom providers.
final class TerminalLinkHandler {
  /// Creates platform-neutral link interaction callbacks.
  const TerminalLinkHandler({
    required this.activate,
    this.hover,
    this.leave,
    this.allowNonHttpProtocols = false,
  });

  /// Invoked when a user activates a link.
  final void Function(Object? event, String text, TerminalBufferRange range)
  activate;

  /// Invoked when a pointer enters a link.
  final void Function(Object? event, String text, TerminalBufferRange range)?
  hover;

  /// Invoked when a pointer leaves a link.
  final void Function(Object? event, String text, TerminalBufferRange range)?
  leave;

  /// Whether schemes other than HTTP and HTTPS may be delivered.
  final bool allowNonHttpProtocols;
}

/// Windows pseudoterminal compatibility information.
final class TerminalWindowsPtyOptions {
  /// Creates Windows PTY compatibility settings.
  const TerminalWindowsPtyOptions({this.backend, this.buildNumber});

  /// PTY backend name, either `conpty` or `winpty`.
  final String? backend;

  /// Windows build number reported by the PTY host.
  final int? buildNumber;
}

/// Optional VT protocol extensions.
final class TerminalVtExtensions {
  /// Creates VT extension settings.
  const TerminalVtExtensions({
    this.kittyKeyboard = false,
    this.kittySgrBoldFaintControl = true,
    this.win32InputMode = false,
    this.colorSchemeQuery = true,
  });

  /// Enables the Kitty keyboard protocol.
  final bool kittyKeyboard;

  /// Enables Kitty's independent bold and faint resets.
  final bool kittySgrBoldFaintControl;

  /// Enables DECSET 9001 win32 input mode.
  final bool win32InputMode;

  /// Enables color-scheme query and notification sequences.
  final bool colorSchemeQuery;
}

/// Compatibility switches for rejected or non-standard terminal behavior.
final class TerminalQuirks {
  /// Creates terminal quirk settings.
  const TerminalQuirks({this.allowSetCursorBlink = false});

  /// Allows DECSET and DECRST 12 to change cursor blinking.
  final bool allowSetCursorBlink;
}

/// Overview ruler border visibility.
final class TerminalOverviewRulerOptions {
  /// Creates overview ruler settings.
  const TerminalOverviewRulerOptions({
    this.showTopBorder = false,
    this.showBottomBorder = false,
  });

  /// Whether the top border is visible.
  final bool showTopBorder;

  /// Whether the bottom border is visible.
  final bool showBottomBorder;
}

/// Scrollbar and overview ruler configuration.
final class TerminalScrollbarOptions {
  /// Creates scrollbar settings.
  const TerminalScrollbarOptions({
    this.showScrollbar = true,
    this.showArrows = false,
    this.width,
    this.overviewRuler,
  });

  /// Whether the scrollbar is visible.
  final bool showScrollbar;

  /// Whether arrow buttons are visible.
  final bool showArrows;

  /// Scrollbar width in logical pixels.
  final double? width;

  /// Optional overview ruler border settings.
  final TerminalOverviewRulerOptions? overviewRuler;
}

/// Security gates for CSI window manipulation and reporting commands.
final class TerminalWindowOptions {
  /// Creates window operation permissions, all disabled by default.
  const TerminalWindowOptions({
    this.restoreWin = false,
    this.minimizeWin = false,
    this.setWinPosition = false,
    this.setWinSizePixels = false,
    this.raiseWin = false,
    this.lowerWin = false,
    this.refreshWin = false,
    this.setWinSizeChars = false,
    this.maximizeWin = false,
    this.fullscreenWin = false,
    this.getWinState = false,
    this.getWinPosition = false,
    this.getWinSizePixels = false,
    this.getScreenSizePixels = false,
    this.getCellSizePixels = false,
    this.getWinSizeChars = false,
    this.getScreenSizeChars = false,
    this.getIconTitle = false,
    this.getWinTitle = false,
    this.pushTitle = false,
    this.popTitle = false,
    this.setWinLines = false,
  });

  /// Allows de-iconifying the window.
  final bool restoreWin;

  /// Allows iconifying the window.
  final bool minimizeWin;

  /// Allows moving the window.
  final bool setWinPosition;

  /// Allows pixel-based resizing.
  final bool setWinSizePixels;

  /// Allows raising the window.
  final bool raiseWin;

  /// Allows lowering the window.
  final bool lowerWin;

  /// Allows explicit window refresh.
  final bool refreshWin;

  /// Allows character-cell resizing.
  final bool setWinSizeChars;

  /// Allows maximizing the window.
  final bool maximizeWin;

  /// Allows changing fullscreen state.
  final bool fullscreenWin;

  /// Allows reporting window state.
  final bool getWinState;

  /// Allows reporting window position.
  final bool getWinPosition;

  /// Allows reporting window pixel dimensions.
  final bool getWinSizePixels;

  /// Allows reporting screen pixel dimensions.
  final bool getScreenSizePixels;

  /// Allows reporting cell pixel dimensions.
  final bool getCellSizePixels;

  /// Allows reporting window dimensions in cells.
  final bool getWinSizeChars;

  /// Allows reporting screen dimensions in cells.
  final bool getScreenSizeChars;

  /// Allows reporting the icon title.
  final bool getIconTitle;

  /// Allows reporting the window title.
  final bool getWinTitle;

  /// Allows pushing a title onto the title stack.
  final bool pushTitle;

  /// Allows popping a title from the title stack.
  final bool popTitle;

  /// Allows changing the number of window lines.
  final bool setWinLines;
}

/// Strings exposed by terminal accessibility surfaces.
final class TerminalLocalizableStrings {
  /// Creates localizable accessibility strings.
  const TerminalLocalizableStrings({
    this.promptLabel = 'Terminal input',
    this.tooMuchOutput =
        'Too much output to announce, navigate to rows manually',
  });

  /// Label for the hidden text input.
  final String promptLabel;

  /// Announcement used when screen-reader output is suppressed.
  final String tooMuchOutput;
}

/// A serializable xterm color theme. Colors use CSS-compatible strings.
final class TerminalColorTheme {
  /// Creates a theme override. Null entries use the xterm defaults.
  const TerminalColorTheme({
    this.foreground,
    this.background,
    this.cursor,
    this.cursorAccent,
    this.selectionBackground,
    this.selectionForeground,
    this.selectionInactiveBackground,
    this.scrollbarSliderBackground,
    this.scrollbarSliderHoverBackground,
    this.scrollbarSliderActiveBackground,
    this.overviewRulerBorder,
    this.black,
    this.red,
    this.green,
    this.yellow,
    this.blue,
    this.magenta,
    this.cyan,
    this.white,
    this.brightBlack,
    this.brightRed,
    this.brightGreen,
    this.brightYellow,
    this.brightBlue,
    this.brightMagenta,
    this.brightCyan,
    this.brightWhite,
    this.extendedAnsi,
  });

  /// xterm-compatible `foreground` API.
  final String? foreground;

  /// xterm-compatible `background` API.
  final String? background;

  /// xterm-compatible `cursor` API.
  final String? cursor;

  /// xterm-compatible `cursorAccent` API.
  final String? cursorAccent;

  /// xterm-compatible `selectionBackground` API.
  final String? selectionBackground;

  /// xterm-compatible `selectionForeground` API.
  final String? selectionForeground;

  /// xterm-compatible `selectionInactiveBackground` API.
  final String? selectionInactiveBackground;

  /// xterm-compatible scrollbar slider color.
  final String? scrollbarSliderBackground;

  /// xterm-compatible hovered scrollbar slider color.
  final String? scrollbarSliderHoverBackground;

  /// xterm-compatible active scrollbar slider color.
  final String? scrollbarSliderActiveBackground;

  /// xterm-compatible overview ruler border color.
  final String? overviewRulerBorder;

  /// xterm-compatible `black` API.
  final String? black;

  /// xterm-compatible `red` API.
  final String? red;

  /// xterm-compatible `green` API.
  final String? green;

  /// xterm-compatible `yellow` API.
  final String? yellow;

  /// xterm-compatible `blue` API.
  final String? blue;

  /// xterm-compatible `magenta` API.
  final String? magenta;

  /// xterm-compatible `cyan` API.
  final String? cyan;

  /// xterm-compatible `white` API.
  final String? white;

  /// xterm-compatible `brightBlack` API.
  final String? brightBlack;

  /// xterm-compatible `brightRed` API.
  final String? brightRed;

  /// xterm-compatible `brightGreen` API.
  final String? brightGreen;

  /// xterm-compatible `brightYellow` API.
  final String? brightYellow;

  /// xterm-compatible `brightBlue` API.
  final String? brightBlue;

  /// xterm-compatible `brightMagenta` API.
  final String? brightMagenta;

  /// xterm-compatible `brightCyan` API.
  final String? brightCyan;

  /// xterm-compatible `brightWhite` API.
  final String? brightWhite;

  /// xterm-compatible `extendedAnsi` API.
  final List<String>? extendedAnsi;
}

/// Replaces the platform objects exposed by an attached terminal view.
///
/// This is the Flutter equivalent of xterm.js' document override. It keeps
/// browser DOM types out of the headless library while allowing embedders and
/// tests to substitute the three observable surface objects.
abstract interface class TerminalDocumentOverride {
  /// Resolves the object exposed as the terminal element.
  Object? resolveElement(Object? element);

  /// Resolves the object exposed as the screen element.
  Object? resolveScreenElement(Object? screenElement);

  /// Resolves the object exposed as the text input element.
  Object? resolveTextarea(Object? textarea);
}

/// Mutable terminal options with the defaults and bounds used by xterm.js.
final class TerminalOptions {
  /// Creates options using xterm.js defaults.
  TerminalOptions({
    bool allowProposedApi = false,
    bool allowTransparency = false,
    bool altClickMovesCursor = true,
    bool convertEol = false,
    bool cursorBlink = false,
    int blinkIntervalDuration = 0,
    TerminalCursorStyle cursorStyle = TerminalCursorStyle.block,
    int cursorWidth = 1,
    TerminalInactiveCursorStyle cursorInactiveStyle =
        TerminalInactiveCursorStyle.outline,
    bool disableStdin = false,
    TerminalDocumentOverride? documentOverride,
    bool drawBoldTextInBrightColors = true,
    double fastScrollSensitivity = 5,
    double fontSize = 15,
    String fontFamily = 'monospace',
    Object fontWeight = 'normal',
    Object fontWeightBold = 'bold',
    bool ignoreBracketedPasteMode = false,
    double letterSpacing = 0,
    double lineHeight = 1,
    TerminalLinkHandler? linkHandler,
    TerminalLogLevel logLevel = TerminalLogLevel.info,
    TerminalLogger? logger,
    bool macOptionIsMeta = false,
    bool macOptionClickForcesSelection = false,
    double minimumContrastRatio = 1,
    bool mouseEventsRequireAlt = false,
    TerminalQuirks quirks = const TerminalQuirks(),
    bool reflowCursorLine = false,
    bool rescaleOverlappingGlyphs = false,
    bool? rightClickSelectsWord,
    bool screenReaderMode = false,
    int scrollback = 1000,
    bool scrollOnEraseInDisplay = false,
    bool scrollOnUserInput = true,
    double scrollSensitivity = 1,
    TerminalScrollbarOptions scrollbar = const TerminalScrollbarOptions(),
    int smoothScrollDuration = 0,
    int tabStopWidth = 8,
    String termName = 'xterm',
    TerminalColorTheme theme = const TerminalColorTheme(),
    TerminalVtExtensions vtExtensions = const TerminalVtExtensions(),
    TerminalWindowsPtyOptions windowsPty = const TerminalWindowsPtyOptions(),
    String wordSeparator = ' ()[]{}\',"`',
    TerminalWindowOptions windowOptions = const TerminalWindowOptions(),
    this.cols = 80,
    this.rows = 24,
    bool showCursorImmediately = false,
  }) : _allowProposedApi = _initial(allowProposedApi),
       _allowTransparency = _initial(allowTransparency),
       _altClickMovesCursor = _initial(altClickMovesCursor),
       _convertEol = _initial(convertEol),
       _cursorBlink = _initial(cursorBlink),
       _cursorStyle = _initial(cursorStyle),
       _cursorInactiveStyle = _initial(cursorInactiveStyle),
       _disableStdin = _initial(disableStdin),
       _documentOverride = _initial(documentOverride),
       _drawBoldTextInBrightColors = _initial(drawBoldTextInBrightColors),
       _fontSize = _initial(fontSize),
       _fontFamily = _initial(fontFamily),
       _fontWeight = _constructorFontWeight(fontWeight, 'normal'),
       _fontWeightBold = _constructorFontWeight(fontWeightBold, 'bold'),
       _ignoreBracketedPasteMode = _initial(ignoreBracketedPasteMode),
       _letterSpacing = _initial(letterSpacing),
       _linkHandler = _initial(linkHandler),
       _logLevel = _initial(logLevel),
       _logger = _initial(logger),
       _macOptionIsMeta = _initial(macOptionIsMeta),
       _macOptionClickForcesSelection = _initial(macOptionClickForcesSelection),
       _mouseEventsRequireAlt = _initial(mouseEventsRequireAlt),
       _quirks = _initial(quirks),
       _reflowCursorLine = _initial(reflowCursorLine),
       _rescaleOverlappingGlyphs = _initial(rescaleOverlappingGlyphs),
       _screenReaderMode = _initial(screenReaderMode),
       _scrollOnEraseInDisplay = _initial(scrollOnEraseInDisplay),
       _scrollOnUserInput = _initial(scrollOnUserInput),
       _scrollbar = _initial(scrollbar),
       _smoothScrollDuration = _initial(smoothScrollDuration),
       _termName = _initial(termName),
       _theme = _initial(theme),
       _vtExtensions = _initial(vtExtensions),
       _windowsPty = _initial(windowsPty),
       _wordSeparator = wordSeparator.isEmpty ? ' ()[]{}\',"`' : wordSeparator,
       _windowOptions = _initial(windowOptions),
       _showCursorImmediately = _initial(showCursorImmediately),
       _blinkIntervalDuration = blinkIntervalDuration < 0
           ? 0
           : blinkIntervalDuration,
       _cursorWidth = cursorWidth < 1 ? 1 : cursorWidth,
       _fastScrollSensitivity = fastScrollSensitivity <= 0
           ? 5
           : fastScrollSensitivity,
       _lineHeight = lineHeight <= 0 ? 1 : lineHeight,
       _minimumContrastRatio = _contrastRatio(minimumContrastRatio),
       _rightClickSelectsWord = rightClickSelectsWord ?? terminalHostIsMac,
       _scrollback = scrollback < 0 ? 1000 : scrollback.clamp(0, 0xffffffff),
       _scrollSensitivity = scrollSensitivity <= 0 ? 1 : scrollSensitivity,
       _tabStopWidth = tabStopWidth < 1 ? 8 : tabStopWidth;

  final TerminalEventEmitter<String> _onChange = TerminalEventEmitter<String>();

  /// Fires with the Dart option name after a value changes.
  TerminalEvent<String> get onChange => _onChange.event;

  /// All runtime option names exposed by this Dart options object.
  List<String> get optionNames => List<String>.unmodifiable(_optionNames);

  /// Listens only for changes to [name] and supplies its new value.
  Disposable onSpecificOptionChange(
    String name,
    void Function(Object? value) listener,
  ) {
    _optionValue(name);
    return _onChange.event.listen((changed) {
      if (changed == name) listener(_optionValue(name));
    });
  }

  /// Runs [listener] when any option in [names] changes.
  Disposable onMultipleOptionChange(
    Iterable<String> names,
    void Function() listener,
  ) {
    final selected = names.toSet()..forEach(_optionValue);
    return _onChange.event.listen((changed) {
      if (selected.contains(changed)) listener();
    });
  }

  static const List<String> _optionNames = <String>[
    'allowProposedApi',
    'allowTransparency',
    'altClickMovesCursor',
    'convertEol',
    'cursorBlink',
    'cursorStyle',
    'cursorInactiveStyle',
    'disableStdin',
    'documentOverride',
    'drawBoldTextInBrightColors',
    'fontSize',
    'fontFamily',
    'fontWeight',
    'fontWeightBold',
    'ignoreBracketedPasteMode',
    'letterSpacing',
    'linkHandler',
    'logLevel',
    'logger',
    'macOptionIsMeta',
    'macOptionClickForcesSelection',
    'mouseEventsRequireAlt',
    'quirks',
    'reflowCursorLine',
    'rescaleOverlappingGlyphs',
    'rightClickSelectsWord',
    'screenReaderMode',
    'scrollOnEraseInDisplay',
    'scrollOnUserInput',
    'scrollbar',
    'smoothScrollDuration',
    'theme',
    'vtExtensions',
    'windowsPty',
    'windowOptions',
    'blinkIntervalDuration',
    'cursorWidth',
    'fastScrollSensitivity',
    'lineHeight',
    'minimumContrastRatio',
    'wordSeparator',
    'scrollback',
    'scrollSensitivity',
    'tabStopWidth',
    'termName',
  ];

  bool _allowProposedApi;
  bool _allowTransparency;
  bool _altClickMovesCursor;
  bool _convertEol;
  bool _cursorBlink;
  int _blinkIntervalDuration;
  TerminalCursorStyle _cursorStyle;
  int _cursorWidth;
  TerminalInactiveCursorStyle _cursorInactiveStyle;
  bool _disableStdin;
  TerminalDocumentOverride? _documentOverride;
  bool _drawBoldTextInBrightColors;
  double _fastScrollSensitivity;
  double _fontSize;
  String _fontFamily;
  Object _fontWeight;
  Object _fontWeightBold;
  bool _ignoreBracketedPasteMode;
  double _letterSpacing;
  double _lineHeight;
  TerminalLinkHandler? _linkHandler;
  TerminalLogLevel _logLevel;
  TerminalLogger? _logger;
  bool _macOptionIsMeta;
  bool _macOptionClickForcesSelection;
  double _minimumContrastRatio;
  bool _mouseEventsRequireAlt;
  TerminalQuirks _quirks;
  bool _reflowCursorLine;
  bool _rescaleOverlappingGlyphs;
  bool _rightClickSelectsWord;
  bool _screenReaderMode;
  int _scrollback;
  bool _scrollOnEraseInDisplay;
  bool _scrollOnUserInput;
  double _scrollSensitivity;
  TerminalScrollbarOptions _scrollbar;
  int _smoothScrollDuration;
  int _tabStopWidth;
  String _termName;
  TerminalColorTheme _theme;
  TerminalVtExtensions _vtExtensions;
  TerminalWindowsPtyOptions _windowsPty;
  String _wordSeparator;
  TerminalWindowOptions _windowOptions;

  /// xterm-compatible `cols` API.
  final int cols;

  /// xterm-compatible `rows` API.
  final int rows;

  /// xterm-compatible `showCursorImmediately` API.
  final bool _showCursorImmediately;

  /// xterm-compatible `allowProposedApi` API.
  bool get allowProposedApi => _allowProposedApi;
  set allowProposedApi(bool value) => _setOption(
    'allowProposedApi',
    _allowProposedApi,
    value,
    (next) => _allowProposedApi = next,
  );

  /// xterm-compatible `allowTransparency` API.
  bool get allowTransparency => _allowTransparency;
  set allowTransparency(bool value) => _setOption(
    'allowTransparency',
    _allowTransparency,
    value,
    (next) => _allowTransparency = next,
  );

  /// Platform surface override used by the Flutter view adapter.
  TerminalDocumentOverride? get documentOverride => _documentOverride;
  set documentOverride(TerminalDocumentOverride? value) => _setOption(
    'documentOverride',
    _documentOverride,
    value,
    (next) => _documentOverride = next,
  );

  /// xterm-compatible `altClickMovesCursor` API.
  bool get altClickMovesCursor => _altClickMovesCursor;
  set altClickMovesCursor(bool value) => _setOption(
    'altClickMovesCursor',
    _altClickMovesCursor,
    value,
    (next) => _altClickMovesCursor = next,
  );

  /// xterm-compatible `convertEol` API.
  bool get convertEol => _convertEol;
  set convertEol(bool value) => _setOption(
    'convertEol',
    _convertEol,
    value,
    (next) => _convertEol = next,
  );

  /// xterm-compatible `cursorBlink` API.
  bool get cursorBlink => _cursorBlink;
  set cursorBlink(bool value) => _setOption(
    'cursorBlink',
    _cursorBlink,
    value,
    (next) => _cursorBlink = next,
  );

  /// xterm-compatible `cursorStyle` API.
  TerminalCursorStyle get cursorStyle => _cursorStyle;
  set cursorStyle(TerminalCursorStyle value) => _setOption(
    'cursorStyle',
    _cursorStyle,
    value,
    (next) => _cursorStyle = next,
  );

  /// xterm-compatible `cursorInactiveStyle` API.
  TerminalInactiveCursorStyle get cursorInactiveStyle => _cursorInactiveStyle;
  set cursorInactiveStyle(TerminalInactiveCursorStyle value) => _setOption(
    'cursorInactiveStyle',
    _cursorInactiveStyle,
    value,
    (next) => _cursorInactiveStyle = next,
  );

  /// xterm-compatible `disableStdin` API.
  bool get disableStdin => _disableStdin;
  set disableStdin(bool value) => _setOption(
    'disableStdin',
    _disableStdin,
    value,
    (next) => _disableStdin = next,
  );

  /// xterm-compatible `drawBoldTextInBrightColors` API.
  bool get drawBoldTextInBrightColors => _drawBoldTextInBrightColors;
  set drawBoldTextInBrightColors(bool value) => _setOption(
    'drawBoldTextInBrightColors',
    _drawBoldTextInBrightColors,
    value,
    (next) => _drawBoldTextInBrightColors = next,
  );

  /// xterm-compatible `fontSize` API.
  double get fontSize => _fontSize;
  set fontSize(double value) =>
      _setOption('fontSize', _fontSize, value, (next) => _fontSize = next);

  /// xterm-compatible `fontFamily` API.
  String get fontFamily => _fontFamily;
  set fontFamily(String value) => _setOption(
    'fontFamily',
    _fontFamily,
    value,
    (next) => _fontFamily = next,
  );

  /// xterm-compatible `ignoreBracketedPasteMode` API.
  bool get ignoreBracketedPasteMode => _ignoreBracketedPasteMode;
  set ignoreBracketedPasteMode(bool value) => _setOption(
    'ignoreBracketedPasteMode',
    _ignoreBracketedPasteMode,
    value,
    (next) => _ignoreBracketedPasteMode = next,
  );

  /// xterm-compatible `letterSpacing` API.
  double get letterSpacing => _letterSpacing;
  set letterSpacing(double value) => _setOption(
    'letterSpacing',
    _letterSpacing,
    value,
    (next) => _letterSpacing = next,
  );

  /// xterm-compatible `linkHandler` API.
  TerminalLinkHandler? get linkHandler => _linkHandler;
  set linkHandler(TerminalLinkHandler? value) => _setOption(
    'linkHandler',
    _linkHandler,
    value,
    (next) => _linkHandler = next,
  );

  /// xterm-compatible `logLevel` API.
  TerminalLogLevel get logLevel => _logLevel;
  set logLevel(TerminalLogLevel value) =>
      _setOption('logLevel', _logLevel, value, (next) => _logLevel = next);

  /// xterm-compatible `logger` API.
  TerminalLogger? get logger => _logger;
  set logger(TerminalLogger? value) =>
      _setOption('logger', _logger, value, (next) => _logger = next);

  /// xterm-compatible `macOptionIsMeta` API.
  bool get macOptionIsMeta => _macOptionIsMeta;
  set macOptionIsMeta(bool value) => _setOption(
    'macOptionIsMeta',
    _macOptionIsMeta,
    value,
    (next) => _macOptionIsMeta = next,
  );

  /// xterm-compatible `macOptionClickForcesSelection` API.
  bool get macOptionClickForcesSelection => _macOptionClickForcesSelection;
  set macOptionClickForcesSelection(bool value) => _setOption(
    'macOptionClickForcesSelection',
    _macOptionClickForcesSelection,
    value,
    (next) => _macOptionClickForcesSelection = next,
  );

  /// xterm-compatible `mouseEventsRequireAlt` API.
  bool get mouseEventsRequireAlt => _mouseEventsRequireAlt;
  set mouseEventsRequireAlt(bool value) => _setOption(
    'mouseEventsRequireAlt',
    _mouseEventsRequireAlt,
    value,
    (next) => _mouseEventsRequireAlt = next,
  );

  /// xterm-compatible `quirks` API.
  TerminalQuirks get quirks => _quirks;
  set quirks(TerminalQuirks value) =>
      _setOption('quirks', _quirks, value, (next) => _quirks = next);

  /// xterm-compatible `reflowCursorLine` API.
  bool get reflowCursorLine => _reflowCursorLine;
  set reflowCursorLine(bool value) => _setOption(
    'reflowCursorLine',
    _reflowCursorLine,
    value,
    (next) => _reflowCursorLine = next,
  );

  /// xterm-compatible `rescaleOverlappingGlyphs` API.
  bool get rescaleOverlappingGlyphs => _rescaleOverlappingGlyphs;
  set rescaleOverlappingGlyphs(bool value) => _setOption(
    'rescaleOverlappingGlyphs',
    _rescaleOverlappingGlyphs,
    value,
    (next) => _rescaleOverlappingGlyphs = next,
  );

  /// xterm-compatible `rightClickSelectsWord` API.
  bool get rightClickSelectsWord => _rightClickSelectsWord;
  set rightClickSelectsWord(bool value) => _setOption(
    'rightClickSelectsWord',
    _rightClickSelectsWord,
    value,
    (next) => _rightClickSelectsWord = next,
  );

  /// xterm-compatible `screenReaderMode` API.
  bool get screenReaderMode => _screenReaderMode;
  set screenReaderMode(bool value) => _setOption(
    'screenReaderMode',
    _screenReaderMode,
    value,
    (next) => _screenReaderMode = next,
  );

  /// xterm-compatible `scrollOnEraseInDisplay` API.
  bool get scrollOnEraseInDisplay => _scrollOnEraseInDisplay;
  set scrollOnEraseInDisplay(bool value) => _setOption(
    'scrollOnEraseInDisplay',
    _scrollOnEraseInDisplay,
    value,
    (next) => _scrollOnEraseInDisplay = next,
  );

  /// xterm-compatible `scrollOnUserInput` API.
  bool get scrollOnUserInput => _scrollOnUserInput;
  set scrollOnUserInput(bool value) => _setOption(
    'scrollOnUserInput',
    _scrollOnUserInput,
    value,
    (next) => _scrollOnUserInput = next,
  );

  /// xterm-compatible `scrollbar` API.
  TerminalScrollbarOptions get scrollbar => _scrollbar;
  set scrollbar(TerminalScrollbarOptions value) =>
      _setOption('scrollbar', _scrollbar, value, (next) => _scrollbar = next);

  /// xterm-compatible `smoothScrollDuration` API.
  int get smoothScrollDuration => _smoothScrollDuration;
  set smoothScrollDuration(int value) => _setOption(
    'smoothScrollDuration',
    _smoothScrollDuration,
    value,
    (next) => _smoothScrollDuration = next,
  );

  /// xterm-compatible `theme` API.
  TerminalColorTheme get theme => _theme;
  set theme(TerminalColorTheme value) =>
      _setOption('theme', _theme, value, (next) => _theme = next);

  /// xterm-compatible `vtExtensions` API.
  TerminalVtExtensions get vtExtensions => _vtExtensions;
  set vtExtensions(TerminalVtExtensions value) => _setOption(
    'vtExtensions',
    _vtExtensions,
    value,
    (next) => _vtExtensions = next,
  );

  /// xterm-compatible `windowsPty` API.
  TerminalWindowsPtyOptions get windowsPty => _windowsPty;
  set windowsPty(TerminalWindowsPtyOptions value) => _setOption(
    'windowsPty',
    _windowsPty,
    value,
    (next) => _windowsPty = next,
  );

  /// xterm-compatible `windowOptions` API.
  TerminalWindowOptions get windowOptions => _windowOptions;
  set windowOptions(TerminalWindowOptions value) => _setOption(
    'windowOptions',
    _windowOptions,
    value,
    (next) => _windowOptions = next,
  );

  /// xterm-compatible `showCursorImmediately` API.
  bool get showCursorImmediately => _showCursorImmediately;

  /// xterm-compatible `blinkIntervalDuration` API.
  int get blinkIntervalDuration => _blinkIntervalDuration;

  /// xterm-compatible `blinkIntervalDuration` API.
  set blinkIntervalDuration(int value) => _set(
    'blinkIntervalDuration',
    _blinkIntervalDuration,
    _nonNegative('blinkIntervalDuration', value),
    (next) => _blinkIntervalDuration = next,
  );

  /// xterm-compatible `cursorWidth` API.
  int get cursorWidth => _cursorWidth;

  /// xterm-compatible `cursorWidth` API.
  set cursorWidth(int value) => _set(
    'cursorWidth',
    _cursorWidth,
    _atLeastOne('cursorWidth', value),
    (next) => _cursorWidth = next,
  );

  /// xterm-compatible `fastScrollSensitivity` API.
  double get fastScrollSensitivity => _fastScrollSensitivity;

  /// xterm-compatible `fastScrollSensitivity` API.
  set fastScrollSensitivity(double value) => _set(
    'fastScrollSensitivity',
    _fastScrollSensitivity,
    _positive('fastScrollSensitivity', value),
    (next) => _fastScrollSensitivity = next,
  );

  /// xterm-compatible `lineHeight` API.
  double get lineHeight => _lineHeight;

  /// xterm-compatible `lineHeight` API.
  set lineHeight(double value) => _set(
    'lineHeight',
    _lineHeight,
    _positive('lineHeight', value),
    (next) => _lineHeight = next,
  );

  /// xterm-compatible `minimumContrastRatio` API.
  double get minimumContrastRatio => _minimumContrastRatio;

  /// xterm-compatible `minimumContrastRatio` API.
  set minimumContrastRatio(double value) => _set(
    'minimumContrastRatio',
    _minimumContrastRatio,
    _contrastRatio(value),
    (next) => _minimumContrastRatio = next,
  );

  /// xterm-compatible `fontWeight` API.
  Object get fontWeight => _fontWeight;

  /// xterm-compatible `fontWeight` API.
  set fontWeight(Object value) => _set(
    'fontWeight',
    _fontWeight,
    _constructorFontWeight(value, 'normal'),
    (next) => _fontWeight = next,
  );

  /// xterm-compatible `fontWeightBold` API.
  Object get fontWeightBold => _fontWeightBold;

  /// xterm-compatible `fontWeightBold` API.
  set fontWeightBold(Object value) => _set(
    'fontWeightBold',
    _fontWeightBold,
    _constructorFontWeight(value, 'bold'),
    (next) => _fontWeightBold = next,
  );

  /// xterm-compatible `wordSeparator` API.
  String get wordSeparator => _wordSeparator;

  /// xterm-compatible `wordSeparator` API.
  set wordSeparator(String value) => _set(
    'wordSeparator',
    _wordSeparator,
    value.isEmpty ? ' ()[]{}\',"`' : value,
    (next) => _wordSeparator = next,
  );

  /// xterm-compatible `scrollback` API.
  int get scrollback => _scrollback;

  /// xterm-compatible `scrollback` API.
  set scrollback(int value) => _set(
    'scrollback',
    _scrollback,
    _boundedScrollback(value),
    (next) => _scrollback = next,
  );

  /// xterm-compatible `scrollSensitivity` API.
  double get scrollSensitivity => _scrollSensitivity;

  /// xterm-compatible `scrollSensitivity` API.
  set scrollSensitivity(double value) => _set(
    'scrollSensitivity',
    _scrollSensitivity,
    _positive('scrollSensitivity', value),
    (next) => _scrollSensitivity = next,
  );

  /// xterm-compatible `tabStopWidth` API.
  int get tabStopWidth => _tabStopWidth;

  /// xterm-compatible `tabStopWidth` API.
  set tabStopWidth(int value) => _set(
    'tabStopWidth',
    _tabStopWidth,
    _atLeastOne('tabStopWidth', value),
    (next) => _tabStopWidth = next,
  );

  /// Terminal identifier used by primary and secondary device attributes.
  String get termName => _termName;
  set termName(String value) =>
      _setOption('termName', _termName, value, (next) => _termName = next);

  void _set<T>(String name, T oldValue, T newValue, void Function(T) assign) {
    _setOption(name, oldValue, newValue, assign);
  }

  Object? _optionValue(String name) => switch (name) {
    'allowProposedApi' => allowProposedApi,
    'allowTransparency' => allowTransparency,
    'altClickMovesCursor' => altClickMovesCursor,
    'convertEol' => convertEol,
    'cursorBlink' => cursorBlink,
    'cursorStyle' => cursorStyle,
    'cursorInactiveStyle' => cursorInactiveStyle,
    'disableStdin' => disableStdin,
    'documentOverride' => documentOverride,
    'drawBoldTextInBrightColors' => drawBoldTextInBrightColors,
    'fontSize' => fontSize,
    'fontFamily' => fontFamily,
    'fontWeight' => fontWeight,
    'fontWeightBold' => fontWeightBold,
    'ignoreBracketedPasteMode' => ignoreBracketedPasteMode,
    'letterSpacing' => letterSpacing,
    'linkHandler' => linkHandler,
    'logLevel' => logLevel,
    'logger' => logger,
    'macOptionIsMeta' => macOptionIsMeta,
    'macOptionClickForcesSelection' => macOptionClickForcesSelection,
    'mouseEventsRequireAlt' => mouseEventsRequireAlt,
    'quirks' => quirks,
    'reflowCursorLine' => reflowCursorLine,
    'rescaleOverlappingGlyphs' => rescaleOverlappingGlyphs,
    'rightClickSelectsWord' => rightClickSelectsWord,
    'screenReaderMode' => screenReaderMode,
    'scrollOnEraseInDisplay' => scrollOnEraseInDisplay,
    'scrollOnUserInput' => scrollOnUserInput,
    'scrollbar' => scrollbar,
    'smoothScrollDuration' => smoothScrollDuration,
    'theme' => theme,
    'vtExtensions' => vtExtensions,
    'windowsPty' => windowsPty,
    'windowOptions' => windowOptions,
    'blinkIntervalDuration' => blinkIntervalDuration,
    'cursorWidth' => cursorWidth,
    'fastScrollSensitivity' => fastScrollSensitivity,
    'lineHeight' => lineHeight,
    'minimumContrastRatio' => minimumContrastRatio,
    'wordSeparator' => wordSeparator,
    'scrollback' => scrollback,
    'scrollSensitivity' => scrollSensitivity,
    'tabStopWidth' => tabStopWidth,
    'termName' => termName,
    _ => throw ArgumentError.value(name, 'name', 'unknown option'),
  };

  void _setOption<T>(
    String name,
    T oldValue,
    T newValue,
    void Function(T) assign,
  ) {
    if (oldValue == newValue) return;
    assign(newValue);
    _onChange.fire(name);
  }

  static T _initial<T>(T value) => value;

  static int _nonNegative(String name, int value) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'cannot be less than 0');
    }
    return value;
  }

  static int _atLeastOne(String name, int value) {
    if (value < 1) {
      throw ArgumentError.value(value, name, 'cannot be less than 1');
    }
    return value;
  }

  static double _positive(String name, double value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'cannot be less than or equal to 0',
      );
    }
    return value;
  }

  static int _boundedScrollback(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'scrollback', 'cannot be less than 0');
    }
    return value.clamp(0, 0xffffffff);
  }

  static bool _isValidFontWeight(Object value) {
    const named = <String>{
      'normal',
      'bold',
      '100',
      '200',
      '300',
      '400',
      '500',
      '600',
      '700',
      '800',
      '900',
    };
    return (value is num && value >= 1 && value <= 1000) ||
        (value is String && named.contains(value));
  }

  static Object _constructorFontWeight(Object value, Object fallback) {
    return _isValidFontWeight(value) ? value : fallback;
  }

  static double _contrastRatio(double value) =>
      (value.clamp(1, 21) * 10).round() / 10;
}
