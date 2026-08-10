import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';

/// Bit flags describing browser mouse events required by a protocol.
abstract final class CoreMouseEventType {
  /// No mouse events.
  static const int none = 0;

  /// Button press events.
  static const int down = 1;

  /// Button release events.
  static const int up = 2;

  /// Motion events with a pressed button.
  static const int drag = 4;

  /// Motion events without a pressed button.
  static const int move = 8;

  /// Wheel events.
  static const int wheel = 16;
}

/// Numeric button values accepted by xterm mouse encodings.
abstract final class CoreMouseButton {
  /// Primary button.
  static const int left = 0;

  /// Middle button.
  static const int middle = 1;

  /// Secondary button.
  static const int right = 2;

  /// No pressed button.
  static const int none = 3;

  /// Wheel pseudo-button.
  static const int wheel = 4;

  /// Auxiliary button 1.
  static const int aux1 = 8;

  /// Auxiliary button 2.
  static const int aux2 = 9;

  /// Auxiliary button 3.
  static const int aux3 = 10;

  /// Auxiliary button 4.
  static const int aux4 = 11;

  /// Auxiliary button 5.
  static const int aux5 = 12;

  /// Auxiliary button 6.
  static const int aux6 = 13;

  /// Auxiliary button 7.
  static const int aux7 = 14;

  /// Auxiliary button 8.
  static const int aux8 = 15;
}

/// Numeric actions accepted by xterm mouse encodings.
abstract final class CoreMouseAction {
  /// Release or upward wheel action.
  static const int up = 0;

  /// Press or downward wheel action.
  static const int down = 1;

  /// Leftward wheel action.
  static const int left = 2;

  /// Rightward wheel action.
  static const int right = 3;

  /// Pointer motion action.
  static const int move = 32;
}

/// Mutable renderer-independent event passed through protocol restrictions.
final class CoreMouseEvent {
  /// Creates an xterm core mouse event.
  CoreMouseEvent({
    required this.column,
    required this.row,
    required this.x,
    required this.y,
    required this.button,
    required this.action,
    this.control = false,
    this.alt = false,
    this.shift = false,
  });

  /// One-based cell column supplied to the encoder.
  int column;

  /// One-based cell row supplied to the encoder.
  int row;

  /// One-based horizontal pixel coordinate.
  int x;

  /// One-based vertical pixel coordinate.
  int y;

  /// A [CoreMouseButton] value.
  int button;

  /// A [CoreMouseAction] value.
  int action;

  /// Control modifier state.
  bool control;

  /// Alt modifier state.
  bool alt;

  /// Shift modifier state.
  bool shift;
}

/// Filtering rules and requested event flags for a mouse protocol.
final class CoreMouseProtocol {
  /// Creates protocol rules.
  const CoreMouseProtocol({required this.events, required this.restrict});

  /// Bitwise [CoreMouseEventType] flags requested by this protocol.
  final int events;

  /// Mutates protocol-specific modifiers and accepts or rejects an event.
  final bool Function(CoreMouseEvent event) restrict;
}

/// Converts one mouse event into a VT report.
typedef CoreMouseEncoding = String Function(CoreMouseEvent event);

/// Owns xterm mouse protocol selection, filtering, and report encoding.
final class MouseStateService extends DisposableStore {
  /// Registers xterm's default protocols and encodings.
  MouseStateService() {
    _protocols.addAll(<String, CoreMouseProtocol>{
      'NONE': CoreMouseProtocol(
        events: CoreMouseEventType.none,
        restrict: (_) => false,
      ),
      'X10': CoreMouseProtocol(
        events: CoreMouseEventType.down,
        restrict: (event) {
          if (event.button == CoreMouseButton.wheel ||
              event.action != CoreMouseAction.down) {
            return false;
          }
          event
            ..control = false
            ..alt = false
            ..shift = false;
          return true;
        },
      ),
      'VT200': CoreMouseProtocol(
        events:
            CoreMouseEventType.down |
            CoreMouseEventType.up |
            CoreMouseEventType.wheel,
        restrict: (event) => event.action != CoreMouseAction.move,
      ),
      'DRAG': CoreMouseProtocol(
        events:
            CoreMouseEventType.down |
            CoreMouseEventType.up |
            CoreMouseEventType.wheel |
            CoreMouseEventType.drag,
        restrict: (event) =>
            event.action != CoreMouseAction.move ||
            event.button != CoreMouseButton.none,
      ),
      'ANY': CoreMouseProtocol(
        events:
            CoreMouseEventType.down |
            CoreMouseEventType.up |
            CoreMouseEventType.wheel |
            CoreMouseEventType.drag |
            CoreMouseEventType.move,
        restrict: (_) => true,
      ),
    });
    _encodings.addAll(<String, CoreMouseEncoding>{
      'DEFAULT': _encodeDefault,
      'SGR': (event) => _encodeSgr(event, pixels: false),
      'SGR_PIXELS': (event) => _encodeSgr(event, pixels: true),
    });
    add(_onProtocolChange);
    reset();
  }

  final Map<String, CoreMouseProtocol> _protocols =
      <String, CoreMouseProtocol>{};
  final Map<String, CoreMouseEncoding> _encodings =
      <String, CoreMouseEncoding>{};
  String _activeProtocol = '';
  String _activeEncoding = '';
  bool Function(Object event)? _customWheelEventHandler;
  final TerminalEventEmitter<int> _onProtocolChange =
      TerminalEventEmitter<int>();

  /// Registered protocol names in insertion order.
  List<String> get protocolNames => List<String>.unmodifiable(_protocols.keys);

  /// Registered encoding names in insertion order.
  List<String> get encodingNames => List<String>.unmodifiable(_encodings.keys);

  /// Fires synchronously with the requested [CoreMouseEventType] flags.
  TerminalEvent<int> get onProtocolChange => _onProtocolChange.event;

  /// Name of the active protocol.
  String get activeProtocol => _activeProtocol;

  /// Activates a registered protocol and synchronously announces its flags.
  set activeProtocol(String name) {
    final protocol = _protocols[name];
    if (protocol == null) throw StateError('unknown protocol "$name"');
    _activeProtocol = name;
    _onProtocolChange.fire(protocol.events);
  }

  /// Name of the active encoding.
  String get activeEncoding => _activeEncoding;

  /// Activates a registered encoding.
  set activeEncoding(String name) {
    if (!_encodings.containsKey(name)) {
      throw StateError('unknown encoding "$name"');
    }
    _activeEncoding = name;
  }

  /// Whether the active protocol requests any events.
  bool get areMouseEventsActive =>
      _protocols[_activeProtocol]!.events != CoreMouseEventType.none;

  /// Whether the single-byte default encoding is active.
  bool get isDefaultEncoding => _activeEncoding == 'DEFAULT';

  /// Whether SGR pixel coordinates are active.
  bool get isPixelEncoding => _activeEncoding == 'SGR_PIXELS';

  /// Adds or replaces a named protocol.
  void addProtocol(String name, CoreMouseProtocol protocol) {
    _protocols[name] = protocol;
  }

  /// Adds or replaces a named encoding.
  void addEncoding(String name, CoreMouseEncoding encoding) {
    _encodings[name] = encoding;
  }

  /// Restores the NONE protocol and DEFAULT encoding.
  void reset() {
    activeProtocol = 'NONE';
    activeEncoding = 'DEFAULT';
  }

  /// Installs the browser wheel veto callback used before mouse reporting.
  // Exact xterm API name is a method, not a Dart property setter.
  // ignore: use_setters_to_change_properties
  void setCustomWheelEventHandler(bool Function(Object event)? handler) {
    _customWheelEventHandler = handler;
  }

  /// Returns whether a browser wheel event is allowed by the custom handler.
  bool allowCustomWheelEvent(Object event) =>
      _customWheelEventHandler?.call(event) != false;

  /// Applies the active protocol's restrictions to [event].
  bool restrictMouseEvent(CoreMouseEvent event) =>
      _protocols[_activeProtocol]!.restrict(event);

  /// Encodes [event] using the active encoding.
  String encodeMouseEvent(CoreMouseEvent event) =>
      _encodings[_activeEncoding]!(event);
}

int _eventCode(CoreMouseEvent event, {required bool sgr}) {
  var code =
      (event.control ? 16 : 0) | (event.shift ? 4 : 0) | (event.alt ? 8 : 0);
  if (event.button == CoreMouseButton.wheel) {
    return code | 64 | event.action;
  }
  code |= event.button & 3;
  if (event.button & 4 != 0) code |= 64;
  if (event.button & 8 != 0) code |= 128;
  if (event.action == CoreMouseAction.move) {
    code |= CoreMouseAction.move;
  } else if (event.action == CoreMouseAction.up && !sgr) {
    code |= CoreMouseButton.none;
  }
  return code;
}

String _encodeDefault(CoreMouseEvent event) {
  final parameters = <int>[
    _eventCode(event, sgr: false) + 32,
    event.column + 32,
    event.row + 32,
  ];
  if (parameters.any((value) => value > 255)) return '';
  return '\u001b[M${String.fromCharCodes(parameters)}';
}

String _encodeSgr(CoreMouseEvent event, {required bool pixels}) {
  final finalByte =
      event.action == CoreMouseAction.up &&
          event.button != CoreMouseButton.wheel
      ? 'm'
      : 'M';
  final column = pixels ? event.x : event.column;
  final row = pixels ? event.y : event.row;
  return '\u001b[<${_eventCode(event, sgr: true)};$column;$row$finalByte';
}
