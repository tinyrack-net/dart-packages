import 'package:vtworld/src/core/kitty_keyboard.dart';

/// Whether a native key event represents a platform third-level shift.
///
/// xterm lets printable macOS Option and Windows AltGr input continue to the
/// text-input boundary, while still handling arrows and other control keys in
/// the terminal. [keyCode] uses the legacy DOM-compatible code range used by
/// the keyboard encoder.
bool isTerminalThirdLevelShift({
  required bool isMac,
  required bool isWindows,
  required bool macOptionIsMeta,
  required bool altKey,
  required bool ctrlKey,
  required bool metaKey,
  required bool altGraph,
  required bool isKeyPress,
  required int keyCode,
}) {
  final thirdLevelKey =
      isMac && !macOptionIsMeta && altKey && !ctrlKey && !metaKey ||
      isWindows && altKey && ctrlKey && !metaKey ||
      isWindows && altGraph;
  if (isKeyPress) return thirdLevelKey;
  return thirdLevelKey && (keyCode == 0 || keyCode > 47);
}

const Map<int, (String, String)> _keyCodeMappings = <int, (String, String)>{
  48: ('0', ')'),
  49: ('1', '!'),
  50: ('2', '@'),
  51: ('3', '#'),
  52: ('4', r'$'),
  53: ('5', '%'),
  54: ('6', '^'),
  55: ('7', '&'),
  56: ('8', '*'),
  57: ('9', '('),
  186: (';', ':'),
  187: ('=', '+'),
  188: (',', '<'),
  189: ('-', '_'),
  190: ('.', '>'),
  191: ('/', '?'),
  192: ('`', '~'),
  219: ('[', '{'),
  // A raw one-character backslash cannot be delimited safely.
  // ignore: use_raw_strings
  220: ('\\', '|'),
  221: (']', '}'),
  222: ("'", '"'),
};

/// Evaluates one key-down event using xterm's legacy keyboard encoder.
KittyKeyboardResult evaluateKeyboardEvent(
  KittyKeyboardEvent event, {
  required bool applicationCursorMode,
  required bool isMac,
  required bool macOptionIsMeta,
}) {
  var type = KittyKeyboardResultType.sendKey;
  var cancel = false;
  String? key;
  final modifiers =
      (event.shiftKey ? 1 : 0) |
      (event.altKey ? 2 : 0) |
      (event.ctrlKey ? 4 : 0) |
      (event.metaKey ? 8 : 0);

  String cursor(String normal, String application, String modified) {
    if (event.metaKey) return '';
    if (modifiers != 0) return '\u001b[1;${modifiers + 1}$modified';
    return applicationCursorMode ? '\u001bO$application' : '\u001b[$normal';
  }

  String functionKey(int number, String? finalByte) {
    if (finalByte != null) {
      return modifiers != 0
          ? '\u001b[1;${modifiers + 1}$finalByte'
          : '\u001bO$finalByte';
    }
    return modifiers != 0
        ? '\u001b[$number;${modifiers + 1}~'
        : '\u001b[$number~';
  }

  switch (event.keyCode) {
    case 0:
      key = switch (event.key) {
        'UIKeyInputUpArrow' => applicationCursorMode ? '\u001bOA' : '\u001b[A',
        'UIKeyInputLeftArrow' =>
          applicationCursorMode ? '\u001bOD' : '\u001b[D',
        'UIKeyInputRightArrow' =>
          applicationCursorMode ? '\u001bOC' : '\u001b[C',
        'UIKeyInputDownArrow' =>
          applicationCursorMode ? '\u001bOB' : '\u001b[B',
        _ => null,
      };
    case 8:
      key = event.ctrlKey ? '\b' : '\x7f';
      if (event.altKey) key = '\u001b$key';
    case 9:
      if (event.shiftKey) {
        key = '\u001b[Z';
      } else {
        key = '\t';
        cancel = true;
      }
    case 13:
      key = event.key == 'c' && event.ctrlKey
          ? '\x03'
          : event.altKey
          ? '\u001b\r'
          : '\r';
      cancel = true;
    case 27:
      key = event.altKey ? '\u001b\u001b' : '\u001b';
      cancel = true;
    case 37:
      key = cursor('D', 'D', 'D');
      if (key.isEmpty) key = null;
    case 39:
      key = cursor('C', 'C', 'C');
      if (key.isEmpty) key = null;
    case 38:
      key = cursor('A', 'A', 'A');
      if (key.isEmpty) key = null;
    case 40:
      key = cursor('B', 'B', 'B');
      if (key.isEmpty) key = null;
    case 45:
      if (!event.shiftKey && !event.ctrlKey) key = '\u001b[2~';
    case 46:
      key = modifiers != 0 ? '\u001b[3;${modifiers + 1}~' : '\u001b[3~';
    case 36:
      key = cursor('H', 'H', 'H');
      if (key.isEmpty) key = null;
    case 35:
      key = cursor('F', 'F', 'F');
      if (key.isEmpty) key = null;
    case 33:
      if (event.shiftKey) {
        type = KittyKeyboardResultType.pageUp;
      } else {
        key = event.ctrlKey ? '\u001b[5;${modifiers + 1}~' : '\u001b[5~';
      }
    case 34:
      if (event.shiftKey) {
        type = KittyKeyboardResultType.pageDown;
      } else {
        key = event.ctrlKey ? '\u001b[6;${modifiers + 1}~' : '\u001b[6~';
      }
    case 112:
      key = functionKey(1, 'P');
    case 113:
      key = functionKey(1, 'Q');
    case 114:
      key = functionKey(1, 'R');
    case 115:
      key = functionKey(1, 'S');
    case 116:
      key = functionKey(15, null);
    case 117:
      key = functionKey(17, null);
    case 118:
      key = functionKey(18, null);
    case 119:
      key = functionKey(19, null);
    case 120:
      key = functionKey(20, null);
    case 121:
      key = functionKey(21, null);
    case 122:
      key = functionKey(23, null);
    case 123:
      key = functionKey(24, null);
    default:
      if (event.ctrlKey && !event.shiftKey && !event.altKey && !event.metaKey) {
        if (event.keyCode >= 65 && event.keyCode <= 90) {
          key = String.fromCharCode(event.keyCode - 64);
        } else if (event.keyCode == 32) {
          key = '\x00';
        } else if (event.keyCode >= 51 && event.keyCode <= 55) {
          key = String.fromCharCode(event.keyCode - 51 + 27);
        } else if (event.keyCode == 56) {
          key = '\x7f';
        } else if (event.key == '/') {
          key = '\x1f';
        } else if (event.keyCode == 219) {
          key = '\u001b';
        } else if (event.keyCode == 220) {
          key = '\x1c';
        } else if (event.keyCode == 221) {
          key = '\x1d';
        }
      } else if ((!isMac || macOptionIsMeta) &&
          event.altKey &&
          !event.metaKey) {
        final mapping = _keyCodeMappings[event.keyCode];
        final mapped = mapping == null
            ? null
            : event.shiftKey
            ? mapping.$2
            : mapping.$1;
        if (mapped != null && mapped.isNotEmpty) {
          key = '\u001b$mapped';
        } else if (event.keyCode >= 65 && event.keyCode <= 90) {
          final code = event.ctrlKey ? event.keyCode - 64 : event.keyCode + 32;
          var value = String.fromCharCode(code);
          if (event.shiftKey) value = value.toUpperCase();
          key = '\u001b$value';
        } else if (event.keyCode == 32) {
          key = '\u001b${event.ctrlKey ? '\x00' : ' '}';
        } else if (event.key == 'Dead' && event.code.startsWith('Key')) {
          var value = event.code.substring(3, 4);
          if (!event.shiftKey) value = value.toLowerCase();
          key = '\u001b$value';
          cancel = true;
        }
      } else if (isMac &&
          !event.altKey &&
          !event.ctrlKey &&
          !event.shiftKey &&
          event.metaKey) {
        if (event.keyCode == 65) type = KittyKeyboardResultType.selectAll;
      } else if (event.key.isNotEmpty &&
          !event.ctrlKey &&
          !event.altKey &&
          !event.metaKey &&
          event.keyCode >= 48 &&
          event.key.length == 1) {
        key = event.key;
      } else if (event.key.isNotEmpty && event.ctrlKey && event.shiftKey) {
        key = switch (event.code) {
          'Minus' => '\x1f',
          'Digit2' => '\x00',
          'Digit6' => '\x1e',
          _ => null,
        };
      }
  }
  return KittyKeyboardResult(type: type, cancel: cancel, key: key);
}
