/// Kitty keyboard protocol enhancement flags.
abstract final class KittyKeyboardFlags {
  /// No enhancements.
  static const int none = 0;

  /// Resolve ambiguous legacy sequences.
  static const int disambiguateEscapeCodes = 0x01;

  /// Include press, repeat, and release types.
  static const int reportEventTypes = 0x02;

  /// Include shifted alternate keys.
  static const int reportAlternateKeys = 0x04;

  /// Encode text-producing keys as CSI-u sequences.
  static const int reportAllKeysAsEscapeCodes = 0x08;

  /// Include the text produced by a key.
  static const int reportAssociatedText = 0x10;
}

/// Kitty keyboard event kind.
enum KittyKeyboardEventType {
  /// Initial key press.
  press(1),

  /// Auto-repeat.
  repeat(2),

  /// Key release.
  release(3);

  /// Creates a protocol event type.
  const KittyKeyboardEventType(this.value);

  /// Numeric value encoded on the wire.
  final int value;
}

/// Kitty modifier bits before the protocol's one-based offset is applied.
abstract final class KittyKeyboardModifiers {
  /// Shift.
  static const int shift = 0x01;

  /// Alt.
  static const int alt = 0x02;

  /// Control.
  static const int control = 0x04;

  /// Super.
  static const int superKey = 0x08;

  /// Hyper.
  static const int hyper = 0x10;

  /// Meta.
  static const int meta = 0x20;

  /// Caps Lock.
  static const int capsLock = 0x40;

  /// Num Lock.
  static const int numLock = 0x80;
}

/// Renderer-independent keyboard input consumed by [KittyKeyboard].
final class KittyKeyboardEvent {
  /// Creates a normalized keyboard event.
  const KittyKeyboardEvent({
    this.altKey = false,
    this.ctrlKey = false,
    this.shiftKey = false,
    this.metaKey = false,
    this.keyCode = 0,
    this.code = '',
    this.key = '',
    this.type = 'keydown',
  });

  /// Whether Alt is active.
  final bool altKey;

  /// Whether Control is active.
  final bool ctrlKey;

  /// Whether Shift is active.
  final bool shiftKey;

  /// Whether Meta/Super is active.
  final bool metaKey;

  /// Legacy numeric key code.
  final int keyCode;

  /// Physical-layout key identifier.
  final String code;

  /// Logical key value.
  final String key;

  /// Native event type name.
  final String type;
}

/// Action category returned from keyboard evaluation.
enum KittyKeyboardResultType {
  /// Send [KittyKeyboardResult.key].
  sendKey,

  /// Select all terminal content.
  selectAll,

  /// Scroll one page upward.
  pageUp,

  /// Scroll one page downward.
  pageDown,
}

/// Result of applying the Kitty keyboard protocol to one event.
final class KittyKeyboardResult {
  /// Creates an evaluation result.
  const KittyKeyboardResult({
    this.type = KittyKeyboardResultType.sendKey,
    this.cancel = false,
    this.key,
  });

  /// Requested action.
  final KittyKeyboardResultType type;

  /// Whether the native event should be cancelled.
  final bool cancel;

  /// Encoded terminal input, if any.
  final String? key;
}

/// xterm.js-compatible Kitty keyboard encoder.
final class KittyKeyboard {
  static const Map<String, int> _functionalKeyCodes = <String, int>{
    'Escape': 27,
    'Enter': 13,
    'Tab': 9,
    'Backspace': 127,
    'CapsLock': 57358,
    'ScrollLock': 57359,
    'NumLock': 57360,
    'PrintScreen': 57361,
    'Pause': 57362,
    'ContextMenu': 57363,
    'F13': 57376,
    'F14': 57377,
    'F15': 57378,
    'F16': 57379,
    'F17': 57380,
    'F18': 57381,
    'F19': 57382,
    'F20': 57383,
    'F21': 57384,
    'F22': 57385,
    'F23': 57386,
    'F24': 57387,
    'F25': 57388,
    'KP_0': 57399,
    'KP_1': 57400,
    'KP_2': 57401,
    'KP_3': 57402,
    'KP_4': 57403,
    'KP_5': 57404,
    'KP_6': 57405,
    'KP_7': 57406,
    'KP_8': 57407,
    'KP_9': 57408,
    'KP_Decimal': 57409,
    'KP_Divide': 57410,
    'KP_Multiply': 57411,
    'KP_Subtract': 57412,
    'KP_Add': 57413,
    'KP_Enter': 57414,
    'KP_Equal': 57415,
    'ShiftLeft': 57441,
    'ShiftRight': 57447,
    'ControlLeft': 57442,
    'ControlRight': 57448,
    'AltLeft': 57443,
    'AltRight': 57449,
    'MetaLeft': 57444,
    'MetaRight': 57450,
    'MediaPlayPause': 57430,
    'MediaStop': 57432,
    'MediaTrackNext': 57435,
    'MediaTrackPrevious': 57436,
    'AudioVolumeDown': 57438,
    'AudioVolumeUp': 57439,
    'AudioVolumeMute': 57440,
  };

  static const Map<String, int> _csiTildeKeys = <String, int>{
    'Insert': 2,
    'Delete': 3,
    'PageUp': 5,
    'PageDown': 6,
    'F5': 15,
    'F6': 17,
    'F7': 18,
    'F8': 19,
    'F9': 20,
    'F10': 21,
    'F11': 23,
    'F12': 24,
  };

  static const Map<String, String> _csiLetterKeys = <String, String>{
    'ArrowUp': 'A',
    'ArrowDown': 'B',
    'ArrowRight': 'C',
    'ArrowLeft': 'D',
    'Home': 'H',
    'End': 'F',
  };

  static const Map<String, String> _ss3FunctionKeys = <String, String>{
    'F1': 'P',
    'F2': 'Q',
    'F3': 'R',
    'F4': 'S',
  };

  int? _getNumpadKeyCode(KittyKeyboardEvent event) {
    if (!event.code.startsWith('Numpad')) return null;
    final suffix = event.code.substring(6);
    if (suffix.length == 1 &&
        suffix.codeUnitAt(0) >= 0x30 &&
        suffix.codeUnitAt(0) <= 0x39) {
      return 57399 + int.parse(suffix);
    }
    return switch (suffix) {
      'Decimal' => 57409,
      'Divide' => 57410,
      'Multiply' => 57411,
      'Subtract' => 57412,
      'Add' => 57413,
      'Enter' => 57414,
      'Equal' => 57415,
      _ => null,
    };
  }

  int? _getModifierKeyCode(KittyKeyboardEvent event) => switch (event.code) {
    'ShiftLeft' => 57441,
    'ShiftRight' => 57447,
    'ControlLeft' => 57442,
    'ControlRight' => 57448,
    'AltLeft' => 57443,
    'AltRight' => 57449,
    'MetaLeft' => 57444,
    'MetaRight' => 57450,
    _ => null,
  };

  int _encodeModifiers(KittyKeyboardEvent event) {
    var modifiers = 0;
    if (event.shiftKey) modifiers |= KittyKeyboardModifiers.shift;
    if (event.altKey) modifiers |= KittyKeyboardModifiers.alt;
    if (event.ctrlKey) modifiers |= KittyKeyboardModifiers.control;
    if (event.metaKey) modifiers |= KittyKeyboardModifiers.superKey;
    return modifiers > 0 ? modifiers + 1 : 0;
  }

  int? _getKeyCode(KittyKeyboardEvent event, bool macOptionAsAlt) {
    final numpadCode = _getNumpadKeyCode(event);
    if (numpadCode != null) return numpadCode;
    final modifierCode = _getModifierKeyCode(event);
    if (modifierCode != null) return modifierCode;
    final functionalCode = _functionalKeyCodes[event.key];
    if (functionalCode != null) return functionalCode;

    if ((event.shiftKey || macOptionAsAlt && event.altKey) &&
        event.code.isNotEmpty) {
      if (event.code.startsWith('Digit') && event.code.length == 6) {
        final digit = event.code.codeUnitAt(5);
        if (digit >= 0x30 && digit <= 0x39) return digit;
      }
      if (event.code.startsWith('Key') && event.code.length == 4) {
        return event.code.substring(3).toLowerCase().codeUnitAt(0);
      }
    }

    if (event.key.length == 1) {
      final code = event.key.runes.first;
      return code >= 65 && code <= 90 ? code + 32 : code;
    }
    return null;
  }

  bool _isModifierKey(KittyKeyboardEvent event) =>
      event.key == 'Shift' ||
      event.key == 'Control' ||
      event.key == 'Alt' ||
      event.key == 'Meta';

  bool _isLockKey(KittyKeyboardEvent event) =>
      event.key == 'CapsLock' ||
      event.key == 'NumLock' ||
      event.key == 'ScrollLock';

  String _buildCsiLetterSequence(
    String letter,
    int modifiers,
    KittyKeyboardEventType eventType,
    bool reportEventTypes,
  ) {
    final needsEventType =
        reportEventTypes && eventType != KittyKeyboardEventType.press;
    if (modifiers > 0 || needsEventType) {
      var sequence = '\u001b[1;${modifiers > 0 ? modifiers : 1}';
      if (needsEventType) sequence += ':${eventType.value}';
      return '$sequence$letter';
    }
    return '\u001b[$letter';
  }

  String _buildSs3Sequence(
    String letter,
    int modifiers,
    KittyKeyboardEventType eventType,
    bool reportEventTypes,
  ) {
    final needsEventType =
        reportEventTypes && eventType != KittyKeyboardEventType.press;
    if (modifiers > 0 || needsEventType) {
      var sequence = '\u001b[1;${modifiers > 0 ? modifiers : 1}';
      if (needsEventType) sequence += ':${eventType.value}';
      return '$sequence$letter';
    }
    return '\u001bO$letter';
  }

  String _buildCsiTildeSequence(
    int number,
    int modifiers,
    KittyKeyboardEventType eventType,
    bool reportEventTypes,
  ) {
    final needsEventType =
        reportEventTypes && eventType != KittyKeyboardEventType.press;
    var sequence = '\u001b[$number';
    if (modifiers > 0 || needsEventType) {
      sequence += ';${modifiers > 0 ? modifiers : 1}';
      if (needsEventType) sequence += ':${eventType.value}';
    }
    return '$sequence~';
  }

  String _buildCsiUSequence(
    KittyKeyboardEvent event,
    int keyCode,
    int modifiers,
    KittyKeyboardEventType eventType,
    int flags,
    bool isFunctional,
    bool isModifier,
  ) {
    final reportEventTypes = flags & KittyKeyboardFlags.reportEventTypes != 0;
    final reportAlternateKeys =
        flags & KittyKeyboardFlags.reportAlternateKeys != 0;
    var sequence = '\u001b[$keyCode';
    if (reportAlternateKeys &&
        event.shiftKey &&
        event.key.length == 1 &&
        !isFunctional &&
        !isModifier) {
      sequence += ':${event.key.runes.first}';
    }

    final reportAssociatedText =
        flags & KittyKeyboardFlags.reportAssociatedText != 0 &&
        eventType != KittyKeyboardEventType.release &&
        event.key.length == 1 &&
        !isFunctional &&
        !isModifier &&
        !event.ctrlKey;
    final textCode = reportAssociatedText ? event.key.runes.first : null;
    final needsEventType =
        reportEventTypes &&
        eventType != KittyKeyboardEventType.press &&
        (eventType == KittyKeyboardEventType.release || textCode == null);

    if (modifiers > 0 || needsEventType || textCode != null) {
      sequence += ';';
      if (modifiers > 0) {
        sequence += '$modifiers';
      } else if (needsEventType) {
        sequence += '1';
      }
      if (needsEventType) sequence += ':${eventType.value}';
    }
    if (textCode != null) sequence += ';$textCode';
    return '${sequence}u';
  }

  /// Evaluates an event according to active Kitty [flags].
  KittyKeyboardResult evaluate(
    KittyKeyboardEvent event,
    int flags, {
    KittyKeyboardEventType eventType = KittyKeyboardEventType.press,
    bool macOptionAsAlt = false,
  }) {
    final modifiers = _encodeModifiers(event);
    final isModifier = _isModifierKey(event);
    final reportEventTypes = flags & KittyKeyboardFlags.reportEventTypes != 0;

    if (!reportEventTypes && eventType == KittyKeyboardEventType.release ||
        isModifier &&
            flags & KittyKeyboardFlags.reportAllKeysAsEscapeCodes == 0 ||
        _isLockKey(event) &&
            flags & KittyKeyboardFlags.reportAllKeysAsEscapeCodes == 0) {
      return const KittyKeyboardResult();
    }

    final csiLetter = _csiLetterKeys[event.key];
    if (csiLetter != null) {
      return KittyKeyboardResult(
        key: _buildCsiLetterSequence(
          csiLetter,
          modifiers,
          eventType,
          reportEventTypes,
        ),
        cancel: true,
      );
    }
    final ss3Letter = _ss3FunctionKeys[event.key];
    if (ss3Letter != null) {
      return KittyKeyboardResult(
        key: _buildSs3Sequence(
          ss3Letter,
          modifiers,
          eventType,
          reportEventTypes,
        ),
        cancel: true,
      );
    }
    final tildeCode = _csiTildeKeys[event.key];
    if (tildeCode != null) {
      return KittyKeyboardResult(
        key: _buildCsiTildeSequence(
          tildeCode,
          modifiers,
          eventType,
          reportEventTypes,
        ),
        cancel: true,
      );
    }

    final keyCode = _getKeyCode(event, macOptionAsAlt);
    if (keyCode == null) return const KittyKeyboardResult();
    final specialKey = keyCode == 13 || keyCode == 9 || keyCode == 127;
    if (specialKey &&
        eventType == KittyKeyboardEventType.release &&
        flags & KittyKeyboardFlags.reportAllKeysAsEscapeCodes == 0) {
      return const KittyKeyboardResult();
    }
    final isFunctional =
        _functionalKeyCodes[event.key] != null ||
        _getNumpadKeyCode(event) != null;
    final useCsiU =
        flags & KittyKeyboardFlags.reportAllKeysAsEscapeCodes != 0 ||
        reportEventTypes && eventType == KittyKeyboardEventType.release ||
        ((flags & KittyKeyboardFlags.disambiguateEscapeCodes != 0 ||
                reportEventTypes) &&
            ((isFunctional && !specialKey) ||
                (modifiers > 0 && event.key.length != 1) ||
                modifiers - 1 > KittyKeyboardModifiers.shift));

    if (useCsiU) {
      return KittyKeyboardResult(
        key: _buildCsiUSequence(
          event,
          keyCode,
          modifiers,
          eventType,
          flags,
          isFunctional,
          isModifier,
        ),
        cancel: true,
      );
    }
    final legacyByte = switch (keyCode) {
      13 => '\r',
      9 => '\t',
      127 => '\x7f',
      _ => null,
    };
    if (legacyByte != null) return KittyKeyboardResult(key: legacyByte);
    if (event.key.length == 1 &&
        !event.ctrlKey &&
        !event.altKey &&
        !event.metaKey) {
      return KittyKeyboardResult(key: event.key);
    }
    return const KittyKeyboardResult();
  }

  /// Whether any protocol enhancement is active.
  static bool shouldUseProtocol(int flags) => flags > 0;
}
