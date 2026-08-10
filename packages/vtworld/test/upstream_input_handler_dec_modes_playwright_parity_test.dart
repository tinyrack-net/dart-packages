import 'package:test/test.dart';

import 'support/input_handler_dec_modes_playwright_cases.dart';

void main() {
  test(
    'Ps = 2 5 - Show cursor (DECTCEM), VT220',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 5 - Show cursor (DECTCEM), VT220',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 4 - Enable XOR of blinking cursor control sequence and menu',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 4 - Enable XOR of blinking cursor control '
      'sequence and menu',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 5 - Disable Graphic Print Color Syntax (DECGPCS), VT340.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 5 - Disable Graphic Print Color Syntax '
      '(DECGPCS), VT340.',
      enabled: false,
    ),
  );
  test(
    'Ps = 8 - No Auto-Repeat Keys (DECARM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 8 - No Auto-Repeat Keys (DECARM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 3 6 - Send ESC   when Meta modifies a key, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 6 - Send ESC   when Meta modifies a key, '
      'xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 3 - 80 Column Mode (DECCOLM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 3 - 80 Column Mode (DECCOLM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 6 - Graphic Print Background Mode, VT340',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 6 - Graphic Print Background Mode, VT340',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 2 - Start blinking cursor (AT&T 610)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 2 - Start blinking cursor (AT&T 610)',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 6 - Start logging (XTLOGGING), xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 6 - Start logging (XTLOGGING), xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 5 - Enable readline character-quoting, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 5 - Enable readline character-quoting, '
      'xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 6 1 - Reset keyboard emulation to Sun/PC style, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 6 1 - Reset keyboard emulation to Sun/PC '
      'style, xterm.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 3 7 - Send VT220 Remove from the editing-keypad Delete key, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 7 - Send VT220 Remove from the '
      'editing-keypad Delete key, xterm.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 3 - Enable raising of the window when Control-G is received, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 3 - Enable raising of the window when '
      'Control-G is received, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 1 6 - Disable SGR Mouse Pixel-Mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 1 6 - Disable SGR Mouse Pixel-Mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Pm = 2 0 0 4, Set bracketed paste mode',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Pm = 2 0 0 4, Set bracketed paste mode',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 5 - No Reverse-wraparound mode (XTREVWRAP), xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 5 - No Reverse-wraparound mode (XTREVWRAP), '
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 2 - Enable National Replacement Character sets (DECNRCM), VT220',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 2 - Enable National Replacement Character '
      'sets (DECNRCM), VT220',
      enabled: true,
    ),
  );
  test(
    "Ps = 9 - Don't send Mouse X & Y on button press, xterm.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 9 - Don't send Mouse X & Y on button press, "
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 3 5 - Enable font-shifting functions (rxvt)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 3 5 - Enable font-shifting functions (rxvt)',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 0 2 - Use Cell Motion Mouse Tracking, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 2 - Use Cell Motion Mouse Tracking, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 6 - Origin Mode (DECOM), VT100',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 - Origin Mode (DECOM), VT100',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 1 - Use the PRIMARY selection, xterm.  This disables the selectToClipboard resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 1 - Use the PRIMARY selection, xterm.  '
      'This disables the selectToClipboard resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 7 - Auto-Wrap Mode (DECAWM), VT100',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 7 - Auto-Wrap Mode (DECAWM), VT100',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 1 5 - Disable urxvt Mouse Mode.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 1 5 - Disable urxvt Mouse Mode.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 3 - Disable blinking cursor (reset only via resource or menu).',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 3 - Disable blinking cursor (reset only via '
      'resource or menu).',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 4 8 - Save cursor as in DECSC, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 8 - Save cursor as in DECSC, xterm',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 3 5 - Disable special modifiers for Alt and NumLock keys, xterm.  This disables the numLock resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 5 - Disable special modifiers for Alt and '
      'NumLock keys, xterm.  This disables the numLock '
      'resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 9 - Limit print to scrolling region (DECPEX), VT220.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 9 - Limit print to scrolling region (DECPEX), '
      'VT220.',
      enabled: false,
    ),
  );
  test(
    'Ps = 3 0 - Show scrollbar (rxvt)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 3 0 - Show scrollbar (rxvt)',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 5 3 - Set SCO function-key mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 3 - Set SCO function-key mode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 5 - Normal Video (DECSCNM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 5 - Normal Video (DECSCNM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 4 - Disable XOR of blinking cursor control sequence and menu.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 4 - Disable XOR of blinking cursor control '
      'sequence and menu.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 1 6 - Enable SGR Mouse PixelMode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 1 6 - Enable SGR Mouse PixelMode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 3 - Enable readline mouse button-3, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 3 - Enable readline mouse button-3, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 5 2 - Set HP function-key mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 2 - Set HP function-key mode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 6 - Disable readline newline pasting, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 6 - Disable readline newline pasting, '
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 7 - No Auto-Wrap Mode (DECAWM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 7 - No Auto-Wrap Mode (DECAWM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 7 - Enable Graphic Rotated Print Mode (DECGRPM), VT340',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 7 - Enable Graphic Rotated Print Mode '
      '(DECGRPM), VT340',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 5 - Hide cursor (DECTCEM), VT220.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 5 - Hide cursor (DECTCEM), VT220.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 0 5 - Disable UTF-8 Mouse Mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 5 - Disable UTF-8 Mouse Mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 1 - more(1) fix (see curses resource)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 1 - more(1) fix (see curses resource)',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 1 5 - Enable urxvt Mouse Mode',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 1 5 - Enable urxvt Mouse Mode',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 3 4 - Don\'t interpret "meta" key, xterm.  This disables the eightBitInput resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 4 - Don\'t interpret "meta" key, xterm.  '
      'This disables the eightBitInput resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 - Smooth (Slow) Scroll (DECSCLM), VT100',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 - Smooth (Slow) Scroll (DECSCLM), VT100',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 0 4 - Send FocusIn/FocusOut events, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 4 - Send FocusIn/FocusOut events, xterm',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 8 - Restore cursor as in DECRC, xterm.  This may be disabled by the titeInhibit resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 8 - Restore cursor as in DECRC, xterm.  '
      'This may be disabled by the titeInhibit resource.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    "Ps = 1 0 0 2 - Don't use Cell Motion Mouse Tracking, xterm.  See the section Button-event tracking.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 0 2 - Don't use Cell Motion Mouse Tracking, "
      'xterm.  See the section Button-event tracking.',
      enabled: false,
    ),
  );
  test(
    'Ps = 6 7 - Backarrow key sends backspace (DECBKM), VT340, VT420',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 7 - Backarrow key sends backspace (DECBKM), '
      'VT340, VT420',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 4 6 - Stop logging (XTLOGGING), xterm.  This is normally disabled by a compile-time option.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 6 - Stop logging (XTLOGGING), xterm.  This is '
      'normally disabled by a compile-time option.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 1 0 - Don\'t scroll to bottom on tty output (rxvt).  This sets the scrollTtyOutput resource to "false".',
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 1 0 - Don't scroll to bottom on tty output "
      '(rxvt).  This sets the scrollTtyOutput resource to '
      '"false".',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 7 - Use Alternate Screen Buffer, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 7 - Use Alternate Screen Buffer, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 9 - Send Mouse X & Y on button press',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 9 - Send Mouse X & Y on button press',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 3 - Start blinking cursor (set only via resource or menu)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 3 - Start blinking cursor (set only via '
      'resource or menu)',
      enabled: true,
    ),
  );
  test(
    "Ps = 1 0 0 4 - Don't send FocusIn/FocusOut events, xterm.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 0 4 - Don't send FocusIn/FocusOut events, "
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 5 0 - Set terminfo/termcap function-key mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 0 - Set terminfo/termcap function-key '
      'mode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 5 1 - Set Sun function-key mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 1 - Set Sun function-key mode, xterm',
      enabled: true,
    ),
  );
  test(
    "Ps = 1 8 - Don't Print Form Feed (DECPFF), VT220.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 8 - Don't Print Form Feed (DECPFF), VT220.",
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 1 1 - Don\'t scroll to bottom on key press (rxvt). This sets the scrollKey resource to "false".',
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 1 1 - Don't scroll to bottom on key press "
      '(rxvt). This sets the scrollKey resource to "false".',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 9 - Set print extent to full screen (DECPEX), VT220',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 9 - Set print extent to full screen (DECPEX), '
      'VT220',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 5 3 - Reset SCO function-key mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 3 - Reset SCO function-key mode, xterm.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    "Ps = 1 0 3 6 - Don't send ESC  when Meta modifies a key, xterm.  This disables the metaSendsEscape resource.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 3 6 - Don't send ESC  when Meta modifies a "
      'key, xterm.  This disables the metaSendsEscape '
      'resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 0 3 - Set Use All Motion (any event) Mouse Tracking',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 3 - Set Use All Motion (any event) Mouse '
      'Tracking',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 5 - Reverse-wraparound mode (XTREVWRAP), xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 5 - Reverse-wraparound mode (XTREVWRAP), '
      'xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 1 - No more(1) fix (see curses resource).',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 1 - No more(1) fix (see curses resource).',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 - Application Cursor Keys (DECCKM), VT100',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 - Application Cursor Keys (DECCKM), VT100',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 6 1 - Set VT220 keyboard emulation, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 6 1 - Set VT220 keyboard emulation, xterm',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 2 - Disable Urgency window manager hint when Control-G is received, xterm.  This disables the bellIsUrgent resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 2 - Disable Urgency window manager hint '
      'when Control-G is received, xterm.  This disables '
      'the bellIsUrgent resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 0 1 - Use Hilite Mouse Tracking, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 1 - Use Hilite Mouse Tracking, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 2 - Enable readline mouse button-2, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 2 - Enable readline mouse button-2, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 3 - Disable readline mouse button-3, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 3 - Disable readline mouse button-3, '
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 6 6 - Application keypad mode (DECNKM), VT320',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 6 - Application keypad mode (DECNKM), VT320',
      enabled: true,
    ),
  );
  test(
    'Ps = 6 - Normal Cursor Mode (DECOM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 - Normal Cursor Mode (DECOM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 4 - Turn off margin bell, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 4 - Turn off margin bell, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 7 - Disable Graphic Rotated Print Mode (DECGRPM), VT340.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 7 - Disable Graphic Rotated Print Mode '
      '(DECGRPM), VT340.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 2 - Enable Urgency window manager hint when Control-G is received, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 2 - Enable Urgency window manager hint '
      'when Control-G is received, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 4 7 - Use Alternate Screen Buffer, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 7 - Use Alternate Screen Buffer, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 1 0 - Scroll to bottom on tty output (rxvt)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 1 0 - Scroll to bottom on tty output (rxvt)',
      enabled: true,
    ),
  );
  test(
    "Ps = 1 0 0 1 - Don't use Hilite Mouse Tracking, xterm.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 0 1 - Don't use Hilite Mouse Tracking, "
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 3 8 - Enter Tektronix mode (DECTEK), VT240, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 3 8 - Enter Tektronix mode (DECTEK), VT240, '
      'xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 4 - Enable Graphic Print Color Mode (DECGPCM), VT340',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 4 - Enable Graphic Print Color Mode '
      '(DECGPCM), VT340',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    "Ps = 1 0 0 0 - Don't send Mouse X & Y on button press and release.  See the section Mouse Tracking.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 0 0 - Don't send Mouse X & Y on button "
      'press and release.  See the section Mouse Tracking.',
      enabled: false,
    ),
  );
  test(
    'Ps = 5 - Reverse Video (DECSCNM), VT100',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 5 - Reverse Video (DECSCNM), VT100',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 6 0 - Set legacy keyboard emulation, i.e, X11R6, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 6 0 - Set legacy keyboard emulation, i.e, '
      'X11R6, xterm',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    "Ps = 1 0 0 3 - Don't use All Motion Mouse Tracking, xterm. See the section Any-event tracking.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 0 3 - Don't use All Motion Mouse Tracking, "
      'xterm. See the section Any-event tracking.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 4 9 - Save cursor as in DECSC, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 9 - Save cursor as in DECSC, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 3 - Enable Graphic Expanded Print Mode (DECGEPM), VT340',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 3 - Enable Graphic Expanded Print Mode '
      '(DECGEPM), VT340',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 3 - Disable Graphic Expanded Print Mode (DECGEPM), VT340.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 3 - Disable Graphic Expanded Print Mode '
      '(DECGEPM), VT340.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 0 7 - Disable Alternate Scroll Mode, xterm.  This corresponds to the alternateScroll resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 7 - Disable Alternate Scroll Mode, xterm. '
      ' This corresponds to the alternateScroll resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 2 0 0 6 - Enable readline newline pasting, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 6 - Enable readline newline pasting, '
      'xterm',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 2 - Designate USASCII for character sets G0-G3 (DECANM), VT100, and set VT100 mode',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 - Designate USASCII for character sets G0-G3 '
      '(DECANM), VT100, and set VT100 mode',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 6 7 - Backarrow key sends delete (DECBKM), VT340, VT420.  This sets the backarrowKey resource to "false".',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 7 - Backarrow key sends delete (DECBKM), '
      'VT340, VT420.  This sets the backarrowKey resource '
      'to "false".',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 2 - Stop blinking cursor (AT&T 610).',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 2 - Stop blinking cursor (AT&T 610).',
      enabled: false,
    ),
  );
  test(
    'Ps = 6 9 - Disable left and right margin mode (DECLRMM), VT420 and up.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 9 - Disable left and right margin mode '
      '(DECLRMM), VT420 and up.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 3 5 - Enable special modifiers for Alt and NumLock keys, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 5 - Enable special modifiers for Alt and '
      'NumLock keys, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 2 - Disable National Replacement Character sets (DECNRCM), VT220.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 2 - Disable National Replacement Character '
      'sets (DECNRCM), VT220.',
      enabled: false,
    ),
  );
  test(
    'Ps = 3 5 - Disable font-shifting functions (rxvt).',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 3 5 - Disable font-shifting functions (rxvt).',
      enabled: false,
    ),
  );
  test(
    'Ps = 2 0 0 2 - Disable readline mouse button-2, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 2 - Disable readline mouse button-2, '
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 - Normal Cursor Keys (DECCKM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 - Normal Cursor Keys (DECCKM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 0 5 - Enable UTF-8 Mouse Mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 5 - Enable UTF-8 Mouse Mode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 - Jump (Fast) Scroll (DECSCLM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 - Jump (Fast) Scroll (DECSCLM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 3 7 - Send DEL from the editing-keypad Delete key, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 7 - Send DEL from the editing-keypad '
      'Delete key, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 7 - Use Normal Screen Buffer, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 7 - Use Normal Screen Buffer, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 4 6 - Enable switching to/from Alternate Screen Buffer, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 6 - Enable switching to/from Alternate '
      'Screen Buffer, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 4 5 - No Extended Reverse-wraparound mode (XTREVWRAP2), xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 5 - No Extended Reverse-wraparound mode '
      '(XTREVWRAP2), xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 3 9 - Send ESC  when Alt modifies a key, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 9 - Send ESC  when Alt modifies a key, '
      'xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 6 0 - Reset legacy keyboard emulation, i.e, X11R6, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 6 0 - Reset legacy keyboard emulation, i.e, '
      'X11R6, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 0 - Disallow 80 ⇒  132 mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 0 - Disallow 80 ⇒  132 mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 0 - Allow 80 ⇒  132 mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 0 - Allow 80 ⇒  132 mode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 4 0 - Keep selection even if not highlighted, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 0 - Keep selection even if not '
      'highlighted, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 6 9 - Enable left and right margin mode (DECLRMM), VT420 and up',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 9 - Enable left and right margin mode '
      '(DECLRMM), VT420 and up',
      enabled: true,
    ),
  );
  test(
    'Ps = 4 5 - Enable Graphic Print Color Syntax (DECGPCS), VT340',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 5 - Enable Graphic Print Color Syntax '
      '(DECGPCS), VT340',
      enabled: true,
    ),
  );
  test(
    'Ps = 8 - Auto-Repeat Keys (DECARM), VT100',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 8 - Auto-Repeat Keys (DECARM), VT100',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 0 - Do not keep selection when not highlighted, xterm.  This disables the keepSelection resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 0 - Do not keep selection when not '
      'highlighted, xterm.  This disables the keepSelection '
      'resource.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 9 - Use Normal Screen Buffer and restore cursor as in DECRC, xterm.  This may be disabled by the titeInhibit resource.  This combines the effects of the 1 0 4 7  and 1 0 4 8  modes.  Use this with terminfo-based applications rather than the 4 7  mode.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 9 - Use Normal Screen Buffer and restore '
      'cursor as in DECRC, xterm.  This may be disabled by '
      'the titeInhibit resource.  This combines the effects '
      'of the 1 0 4 7  and 1 0 4 8  modes.  Use this with '
      'terminfo-based applications rather than the 4 7  '
      'mode.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 5 0 - Reset terminfo/termcap function-key mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 0 - Reset terminfo/termcap function-key '
      'mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 4 4 - Reuse the most recent data copied to CLIPBOARD, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 4 - Reuse the most recent data copied to '
      'CLIPBOARD, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 8 - Print Form Feed (DECPFF), VT220',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 8 - Print Form Feed (DECPFF), VT220',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 0 7 - Enable Alternate Scroll Mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 7 - Enable Alternate Scroll Mode, xterm',
      enabled: true,
    ),
  );
  test(
    "Ps = 3 0 - Don't show scrollbar (rxvt).",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 3 0 - Don't show scrollbar (rxvt).",
      enabled: false,
    ),
  );
  test(
    'Ps = 2 - Designate VT52 mode (DECANM), VT100.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 - Designate VT52 mode (DECANM), VT100.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 0 6 - Disable SGR Mouse Mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 6 - Disable SGR Mouse Mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 4 - Turn on margin bell, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 4 - Turn on margin bell, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 3 4 - Interpret "meta" key, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 3 4 - Interpret "meta" key, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 1 - Disable readline mouse button-1, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 1 - Disable readline mouse button-1, '
      'xterm.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 3 - Disable raising of the window when Control- G is received, xterm.  This disables the popOnBell resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 3 - Disable raising of the window when '
      'Control- G is received, xterm.  This disables the '
      'popOnBell resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 3 - 132 Column Mode (DECCOLM), VT100',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 3 - 132 Column Mode (DECCOLM), VT100',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 4 1 - Use the CLIPBOARD selection, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 1 - Use the CLIPBOARD selection, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 5 2 - Reset HP function-key mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 2 - Reset HP function-key mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 9 5 - Do not clear screen when DECCOLM is set/reset (DECNCSM), VT510 and up',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 9 5 - Do not clear screen when DECCOLM is '
      'set/reset (DECNCSM), VT510 and up',
      enabled: true,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    "Ps = 1 0 3 9 - Don't send ESC when Alt modifies a key, xterm.  This disables the altSendsEscape resource.",
    () => verifyInputHandlerDecModePlaywrightCase(
      "Ps = 1 0 3 9 - Don't send ESC when Alt modifies a "
      'key, xterm.  This disables the altSendsEscape '
      'resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 5 1 - Reset Sun function-key mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 5 1 - Reset Sun function-key mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 - Show toolbar (rxvt)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 - Show toolbar (rxvt)',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 4 - Reset bracketed paste mode, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 4 - Reset bracketed paste mode, xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 0 0 - Send Mouse X & Y on button press and release',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 0 - Send Mouse X & Y on button press and '
      'release',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 0 6 - Enable SGR Mouse Mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 0 6 - Enable SGR Mouse Mode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 9 5 - Clear screen when DECCOLM is set/reset (DECNCSM), VT510 and up.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 9 5 - Clear screen when DECCOLM is set/reset '
      '(DECNCSM), VT510 and up.',
      enabled: false,
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 1 0 4 7 - Use Normal Screen Buffer, xterm.  Clear the screen first if in the Alternate Screen Buffer.  This may be disabled by the titeInhibit resource.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 7 - Use Normal Screen Buffer, xterm.  '
      'Clear the screen first if in the Alternate Screen '
      'Buffer.  This may be disabled by the titeInhibit '
      'resource.',
      enabled: false,
    ),
  );
  test(
    'Ps = 6 6 - Numeric keypad mode (DECNKM), VT320.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 6 6 - Numeric keypad mode (DECNKM), VT320.',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 4 6 - Disable switching to/from Alternate Screen Buffer, xterm.  This works for terminfo-based systems, updating the titeInhibit resource.  If currently using the Alternate Screen Buffer, xterm switches to the Normal Screen Buffer.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 6 - Disable switching to/from Alternate '
      'Screen Buffer, xterm.  This works for terminfo-based '
      'systems, updating the titeInhibit resource.  If '
      'currently using the Alternate Screen Buffer, xterm '
      'switches to the Normal Screen Buffer.',
      enabled: false,
    ),
  );
  test(
    'Ps = 2 0 0 1 - Enable readline mouse button-1, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 1 - Enable readline mouse button-1, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 4 5 - XTREVWRAP2: Extended Reverse-wraparound mode, xterm',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 4 5 - XTREVWRAP2: Extended '
      'Reverse-wraparound mode, xterm',
      enabled: true,
    ),
  );
  test(
    'Ps = 1 0 - Hide toolbar (rxvt).',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 - Hide toolbar (rxvt).',
      enabled: false,
    ),
  );
  test(
    'Ps = 1 0 1 1 - Scroll to bottom on key press (rxvt)',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 1 0 1 1 - Scroll to bottom on key press (rxvt)',
      enabled: true,
    ),
  );
  test(
    'Ps = 2 0 0 5 - Disable readline character-quoting, xterm.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 2 0 0 5 - Disable readline character-quoting, '
      'xterm.',
      enabled: false,
    ),
  );
  test(
    'Ps = 4 4 - Disable Graphic Print Color Mode (DECGPCM), VT340.',
    () => verifyInputHandlerDecModePlaywrightCase(
      'Ps = 4 4 - Disable Graphic Print Color Mode '
      '(DECGPCM), VT340.',
      enabled: false,
    ),
  );
}
