import 'package:vtworld/src/core/buffer.dart';
import 'package:vtworld/src/core/kitty_keyboard.dart';
import 'package:vtworld/src/core/options.dart';

/// Win32 console control-key-state flags.
abstract final class Win32ControlKeyState {
  /// Right Alt is pressed.
  static const int rightAltPressed = 0x001;

  /// Left Alt is pressed.
  static const int leftAltPressed = 0x002;

  /// Right Control is pressed.
  static const int rightControlPressed = 0x004;

  /// Left Control is pressed.
  static const int leftControlPressed = 0x008;

  /// Shift is pressed.
  static const int shiftPressed = 0x010;

  /// Num Lock is enabled.
  static const int numLockOn = 0x020;

  /// Scroll Lock is enabled.
  static const int scrollLockOn = 0x040;

  /// Caps Lock is enabled.
  static const int capsLockOn = 0x080;

  /// The key belongs to the enhanced-key set.
  static const int enhancedKey = 0x100;
}

/// Encoder for ConPTY's Win32 input mode (`CSI ... _`).
final class Win32InputMode {
  static const Map<String, int> _virtualKeys = <String, int>{
    'NumpadMultiply': 0x6a,
    'NumpadAdd': 0x6b,
    'NumpadSeparator': 0x6c,
    'NumpadSubtract': 0x6d,
    'NumpadDecimal': 0x6e,
    'NumpadDivide': 0x6f,
    'NumpadEnter': 0x0d,
    'NumLock': 0x90,
    'ArrowUp': 0x26,
    'ArrowDown': 0x28,
    'ArrowLeft': 0x25,
    'ArrowRight': 0x27,
    'Home': 0x24,
    'End': 0x23,
    'PageUp': 0x21,
    'PageDown': 0x22,
    'Insert': 0x2d,
    'Delete': 0x2e,
    'ShiftLeft': 0x10,
    'ShiftRight': 0x10,
    'ControlLeft': 0x11,
    'ControlRight': 0x11,
    'AltLeft': 0x12,
    'AltRight': 0x12,
    'MetaLeft': 0x5b,
    'MetaRight': 0x5c,
    'CapsLock': 0x14,
    'ScrollLock': 0x91,
    'Escape': 0x1b,
    'Enter': 0x0d,
    'Tab': 0x09,
    'Space': 0x20,
    'Backspace': 0x08,
    'Pause': 0x13,
    'ContextMenu': 0x5d,
    'PrintScreen': 0x2c,
    'Semicolon': 0xba,
    'Equal': 0xbb,
    'Comma': 0xbc,
    'Minus': 0xbd,
    'Period': 0xbe,
    'Slash': 0xbf,
    'Backquote': 0xc0,
    'BracketLeft': 0xdb,
    'Backslash': 0xdc,
    'BracketRight': 0xdd,
    'Quote': 0xde,
    'IntlBackslash': 0xe2,
  };

  static const Map<String, int> _scanCodes = <String, int>{
    'KeyQ': 0x10,
    'KeyW': 0x11,
    'KeyE': 0x12,
    'KeyR': 0x13,
    'KeyT': 0x14,
    'KeyY': 0x15,
    'KeyU': 0x16,
    'KeyI': 0x17,
    'KeyO': 0x18,
    'KeyP': 0x19,
    'KeyA': 0x1e,
    'KeyS': 0x1f,
    'KeyD': 0x20,
    'KeyF': 0x21,
    'KeyG': 0x22,
    'KeyH': 0x23,
    'KeyJ': 0x24,
    'KeyK': 0x25,
    'KeyL': 0x26,
    'KeyZ': 0x2c,
    'KeyX': 0x2d,
    'KeyC': 0x2e,
    'KeyV': 0x2f,
    'KeyB': 0x30,
    'KeyN': 0x31,
    'KeyM': 0x32,
    'Digit1': 0x02,
    'Digit2': 0x03,
    'Digit3': 0x04,
    'Digit4': 0x05,
    'Digit5': 0x06,
    'Digit6': 0x07,
    'Digit7': 0x08,
    'Digit8': 0x09,
    'Digit9': 0x0a,
    'Digit0': 0x0b,
    'F1': 0x3b,
    'F2': 0x3c,
    'F3': 0x3d,
    'F4': 0x3e,
    'F5': 0x3f,
    'F6': 0x40,
    'F7': 0x41,
    'F8': 0x42,
    'F9': 0x43,
    'F10': 0x44,
    'F11': 0x57,
    'F12': 0x58,
    'Numpad0': 0x52,
    'Numpad1': 0x4f,
    'Numpad2': 0x50,
    'Numpad3': 0x51,
    'Numpad4': 0x4b,
    'Numpad5': 0x4c,
    'Numpad6': 0x4d,
    'Numpad7': 0x47,
    'Numpad8': 0x48,
    'Numpad9': 0x49,
    'NumpadMultiply': 0x37,
    'NumpadAdd': 0x4e,
    'NumpadSubtract': 0x4a,
    'NumpadDecimal': 0x53,
    'NumpadDivide': 0x35,
    'NumpadEnter': 0x1c,
    'NumLock': 0x45,
    'ArrowUp': 0x48,
    'ArrowDown': 0x50,
    'ArrowLeft': 0x4b,
    'ArrowRight': 0x4d,
    'Home': 0x47,
    'End': 0x4f,
    'PageUp': 0x49,
    'PageDown': 0x51,
    'Insert': 0x52,
    'Delete': 0x53,
    'ShiftLeft': 0x2a,
    'ShiftRight': 0x36,
    'ControlLeft': 0x1d,
    'ControlRight': 0x1d,
    'AltLeft': 0x38,
    'AltRight': 0x38,
    'CapsLock': 0x3a,
    'ScrollLock': 0x46,
    'Escape': 0x01,
    'Enter': 0x1c,
    'Tab': 0x0f,
    'Space': 0x39,
    'Backspace': 0x0e,
    'Pause': 0x45,
    'Semicolon': 0x27,
    'Equal': 0x0d,
    'Comma': 0x33,
    'Minus': 0x0c,
    'Period': 0x34,
    'Slash': 0x35,
    'Backquote': 0x29,
    'BracketLeft': 0x1a,
    'Backslash': 0x2b,
    'BracketRight': 0x1b,
    'Quote': 0x28,
  };

  static const Set<String> _enhancedKeys = <String>{
    'ArrowUp',
    'ArrowDown',
    'ArrowLeft',
    'ArrowRight',
    'Home',
    'End',
    'PageUp',
    'PageDown',
    'Insert',
    'Delete',
    'NumpadEnter',
    'NumpadDivide',
    'ControlRight',
    'AltRight',
    'PrintScreen',
    'Pause',
    'ContextMenu',
    'MetaLeft',
    'MetaRight',
  };

  static const Map<String, int> _controlCharacters = <String, int>{
    'Enter': 0x0d,
    'Backspace': 0x08,
    'Tab': 0x09,
    'Escape': 0x1b,
  };

  int _virtualKey(KittyKeyboardEvent event) {
    final code = event.code;
    if (code.length == 4 && code.startsWith('Key')) {
      final letter = code.codeUnitAt(3);
      if (letter >= 0x41 && letter <= 0x5a) return letter;
    }
    if (code.length == 6 && code.startsWith('Digit')) {
      final digit = code.codeUnitAt(5);
      if (digit >= 0x30 && digit <= 0x39) return digit;
    }
    if (code.startsWith('F')) {
      final number = int.tryParse(code.substring(1));
      if (number != null && number >= 1 && number <= 24) {
        return 0x6f + number;
      }
    }
    if (code.startsWith('Numpad') && code.length == 7) {
      final digit = code.codeUnitAt(6);
      if (digit >= 0x30 && digit <= 0x39) return 0x60 + digit - 0x30;
    }
    return _virtualKeys[code] ?? event.keyCode;
  }

  int _unicodeCharacter(KittyKeyboardEvent event) {
    if (event.ctrlKey && !event.altKey && !event.metaKey) {
      if (event.key == 'Enter') return 0x0a;
      if (event.key == 'Backspace') return 0x7f;
    }
    final control = _controlCharacters[event.key];
    if (control != null) return control;
    if (event.key.length != 1) return 0;
    final codePoint = event.key.codeUnitAt(0);
    if (event.ctrlKey && !event.altKey && !event.metaKey) {
      if (codePoint >= 0x41 && codePoint <= 0x5a) return codePoint - 0x40;
      if (codePoint >= 0x61 && codePoint <= 0x7a) return codePoint - 0x60;
    }
    return codePoint;
  }

  int _controlKeyState(KittyKeyboardEvent event) {
    var state = 0;
    if (event.shiftKey) state |= Win32ControlKeyState.shiftPressed;
    if (event.ctrlKey) {
      state |= event.code == 'ControlRight'
          ? Win32ControlKeyState.rightControlPressed
          : Win32ControlKeyState.leftControlPressed;
    }
    if (event.altKey) {
      state |= event.code == 'AltRight'
          ? Win32ControlKeyState.rightAltPressed
          : Win32ControlKeyState.leftAltPressed;
    }
    if (_enhancedKeys.contains(event.code)) {
      state |= Win32ControlKeyState.enhancedKey;
    }
    return state;
  }

  /// Encodes one key-down or key-up event.
  KittyKeyboardResult evaluateKeyboardEvent(
    KittyKeyboardEvent event, {
    required bool isKeyDown,
  }) {
    final virtualKey = _virtualKey(event);
    final scanCode = _scanCodes[event.code] ?? 0;
    final unicodeCharacter = _unicodeCharacter(event);
    final keyDown = isKeyDown ? 1 : 0;
    final controlState = _controlKeyState(event);
    return KittyKeyboardResult(
      cancel: true,
      key:
          '\u001b[$virtualKey;$scanCode;$unicodeCharacter;'
          '$keyDown;$controlState;1_',
    );
  }
}

/// Whether xterm's legacy ConPTY wrapped-line heuristic is required.
bool usesWindowsWrappingHeuristics(TerminalWindowsPtyOptions options) =>
    options.backend == 'conpty' &&
    options.buildNumber != null &&
    options.buildNumber! < 21376;

/// Updates the current line's wrapped state from the preceding line's final
/// cell, matching xterm.js' legacy Windows PTY behavior.
void updateWindowsModeWrappedState(TerminalBuffer buffer, int columns) {
  final previous = buffer.getLine(buffer.absoluteCursorY - 1);
  final lastCell = previous?.getCell(columns - 1);
  final next = buffer.getLine(buffer.absoluteCursorY);
  if (next != null && lastCell != null) {
    next.isWrapped = lastCell.code != 0 && lastCell.code != 0x20;
  }
}
