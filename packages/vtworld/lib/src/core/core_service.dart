import 'package:vtworld/src/core/disposable.dart';
import 'package:vtworld/src/core/event.dart';
import 'package:vtworld/src/core/options.dart';

/// Mutable ANSI mode state owned by [CoreService].
final class CoreModes {
  /// Whether insert mode is active.
  bool insertMode = false;
}

/// Mutable DEC private mode state owned by [CoreService].
final class CoreDecPrivateModes {
  /// Application cursor key mode.
  bool applicationCursorKeys = false;

  /// Application keypad mode.
  bool applicationKeypad = false;

  /// Bracketed paste mode.
  bool bracketedPasteMode = false;

  /// Whether OSC color scheme update reports are enabled.
  bool colorSchemeUpdates = false;

  /// Explicit cursor blink override.
  bool? cursorBlink;

  /// Explicit cursor style override.
  String? cursorStyle;

  /// Origin mode.
  bool origin = false;

  /// Reverse wraparound mode.
  bool reverseWraparound = false;

  /// Focus reporting mode.
  bool sendFocus = false;

  /// Synchronized output mode.
  bool synchronizedOutput = false;

  /// Win32 input compatibility mode.
  bool win32InputMode = false;

  /// Automatic wraparound mode.
  bool wraparound = true;
}

/// Kitty keyboard protocol state for normal and alternate buffers.
final class CoreKittyKeyboardState {
  /// Currently active flags.
  int flags = 0;

  /// Saved normal-buffer flags.
  int mainFlags = 0;

  /// Saved alternate-buffer flags.
  int altFlags = 0;

  /// Normal-buffer push/pop stack.
  final List<int> mainStack = <int>[];

  /// Alternate-buffer push/pop stack.
  final List<int> altStack = <int>[];
}

/// Owns terminal modes and synchronous input events.
final class CoreService extends DisposableStore {
  /// Creates core state from terminal [options].
  CoreService({
    required this.options,
    int Function()? bufferBaseY,
    int Function()? bufferDisplayY,
  }) : _bufferBaseY = bufferBaseY ?? _zero,
       _bufferDisplayY = bufferDisplayY ?? _zero,
       isCursorInitialized = options.showCursorImmediately {
    _onData = add(TerminalEventEmitter<String>());
    _onUserInput = add(TerminalEventEmitter<TerminalVoid>());
    _onBinary = add(TerminalEventEmitter<String>());
    _onRequestScrollToBottom = add(TerminalEventEmitter<TerminalVoid>());
  }

  /// Effective terminal options.
  final TerminalOptions options;
  final int Function() _bufferBaseY;
  final int Function() _bufferDisplayY;

  late final TerminalEventEmitter<String> _onData;
  late final TerminalEventEmitter<TerminalVoid> _onUserInput;
  late final TerminalEventEmitter<String> _onBinary;
  late final TerminalEventEmitter<TerminalVoid> _onRequestScrollToBottom;

  /// Application text output.
  TerminalEvent<String> get onData => _onData.event;

  /// Notification sent before user-originated [onData].
  TerminalEvent<TerminalVoid> get onUserInput => _onUserInput.event;

  /// Application binary output.
  TerminalEvent<String> get onBinary => _onBinary.event;

  /// Request to reveal the bottom before user input is emitted.
  TerminalEvent<TerminalVoid> get onRequestScrollToBottom =>
      _onRequestScrollToBottom.event;

  /// Whether cursor rendering has been initialized.
  bool isCursorInitialized;

  /// Whether the cursor is temporarily hidden.
  bool isCursorHidden = false;

  /// ANSI modes.
  CoreModes modes = CoreModes();

  /// DEC private modes.
  CoreDecPrivateModes decPrivateModes = CoreDecPrivateModes();

  /// Kitty keyboard state.
  CoreKittyKeyboardState kittyKeyboard = CoreKittyKeyboardState();

  /// Restores mode defaults without changing cursor initialization state.
  void reset() {
    modes = CoreModes();
    decPrivateModes = CoreDecPrivateModes();
    kittyKeyboard = CoreKittyKeyboardState();
  }

  /// Emits application text, preserving xterm's scroll/user/data order.
  void triggerDataEvent(String data, {bool wasUserInput = false}) {
    if (options.disableStdin) return;
    if (wasUserInput &&
        options.scrollOnUserInput &&
        _bufferBaseY() != _bufferDisplayY()) {
      _onRequestScrollToBottom.fire(TerminalVoid.value);
    }
    if (wasUserInput) _onUserInput.fire(TerminalVoid.value);
    _onData.fire(data);
  }

  /// Emits application binary data unless stdin is disabled.
  void triggerBinaryEvent(String data) {
    if (options.disableStdin) return;
    _onBinary.fire(data);
  }

  static int _zero() => 0;
}
