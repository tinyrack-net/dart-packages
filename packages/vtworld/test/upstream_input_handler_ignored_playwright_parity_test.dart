import 'package:test/test.dart';

import 'support/input_handler_ignored_playwright_cases.dart';

void main() {
  test(
    'CSI Ps SP t - Set warning-bell volume (DECSWBV), VT520.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps SP t - Set warning-bell volume (DECSWBV), '
      'VT520.',
    ),
  );
  test(
    'CSI > Pm T - XTRMTITLE: Reset title mode features to default value, xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI > Pm T - XTRMTITLE: Reset title mode features to '
      'default value, xterm',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI [Pm] # p - Push video attributes onto stack (XTPUSHSGR), xterm.  This is an alias for CSI # { , used to work around language limitations of C#.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI [Pm] # p - Push video attributes onto stack '
      '(XTPUSHSGR), xterm.  This is an alias for CSI # { , '
      'used to work around language limitations of C#.',
    ),
  );
  test(
    'CSI # } - Pop video attributes from stack (XTPOPSGR), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI # } - Pop video attributes from stack '
      '(XTPOPSGR), xterm.',
    ),
  );
  test(
    'CSI Ps q - Load LEDs (DECLL), VT100.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps q - Load LEDs (DECLL), VT100.',
    ),
  );
  test(
    'CSI ? Ps i - MC: Media Copy, DEC-specified',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI ? Ps i - MC: Media Copy, DEC-specified',
    ),
  );
  test(
    'CSI # q - Pop video attributes from stack (XTPOPSGR), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI # q - Pop video attributes from stack '
      '(XTPOPSGR), xterm.',
    ),
  );
  test(
    'CSI Ps * | - Select number of lines per screen (DECSNLS), VT420 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps * | - Select number of lines per screen '
      '(DECSNLS), VT420 and up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    r'CSI Pt ; Pl ; Pb ; Pr $ z - Erase Rectangular Area (DECERA), VT400 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Pt ; Pl ; Pb ; Pr $ z - Erase Rectangular Area '
      '(DECERA), VT400 and up.',
    ),
  );
  test(
    'CSI Ps * x - Select Attribute Change Extent (DECSACE), VT420 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps * x - Select Attribute Change Extent '
      '(DECSACE), VT420 and up.',
    ),
  );
  test(
    r'CSI Ps $ } - Select active status display (DECSASD), VT320 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Ps $ } - Select active status display (DECSASD), '
      'VT320 and up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    r'CSI Pt ; Pl ; Pb ; Pr ; Pm $ t - Reverse Attributes in Rectangular Area (DECRARA), VT400 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Pt ; Pl ; Pb ; Pr ; Pm $ t - Reverse Attributes '
      'in Rectangular Area (DECRARA), VT400 and up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI Ps ; Ps ; Ps ; Ps ; Ps T - XTHIMOUSE: Initiate highlight mouse tracking (XTHIMOUSE), xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps ; Ps ; Ps ; Ps ; Ps T - XTHIMOUSE: Initiate '
      'highlight mouse tracking (XTHIMOUSE), xterm',
    ),
  );
  test(
    "CSI Ps ' | - Request Locator Position (DECRQLP).",
    () => verifyInputHandlerIgnoredPlaywrightCase(
      "CSI Ps ' | - Request Locator Position (DECRQLP).",
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    r'CSI Pc ; Pt ; Pl ; Pb ; Pr $ x - Fill Rectangular Area (DECFRA), VT420 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Pc ; Pt ; Pl ; Pb ; Pr $ x - Fill Rectangular '
      'Area (DECFRA), VT420 and up.',
    ),
  );
  test(
    "CSI Pm ' { - Select Locator Events (DECSLE).",
    () => verifyInputHandlerIgnoredPlaywrightCase(
      "CSI Pm ' { - Select Locator Events (DECSLE).",
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    "CSI Pt ; Pl ; Pb ; Pr ' w - Enable Filter Rectangle (DECEFR), VT420 and up.",
    () => verifyInputHandlerIgnoredPlaywrightCase(
      "CSI Pt ; Pl ; Pb ; Pr ' w - Enable Filter Rectangle "
      '(DECEFR), VT420 and up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI Pt ; Pl ; Pb ; Pr # | - Report selected graphic rendition (XTREPORTSGR), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Pt ; Pl ; Pb ; Pr # | - Report selected graphic '
      'rendition (XTREPORTSGR), xterm.',
    ),
  );
  test(
    'CSI Ps SP u - Set margin-bell volume (DECSMBV), VT520.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps SP u - Set margin-bell volume (DECSMBV), '
      'VT520.',
    ),
  );
  test(
    'CSI ? Pm r - Restore DEC Private Mode Values (XTRESTORE), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI ? Pm r - Restore DEC Private Mode Values '
      '(XTRESTORE), xterm.',
    ),
  );
  test(
    'CSI > Pp [; Pv] m - XTMODKEYS: Set/reset key modifier options, xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI > Pp [; Pv] m - XTMODKEYS: Set/reset key '
      'modifier options, xterm',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI Pi ; Pg ; Pt ; Pl ; Pb ; Pr * y - Request Checksum of Rectangular Area (DECRQCRA), VT420 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Pi ; Pg ; Pt ; Pl ; Pb ; Pr * y - Request '
      'Checksum of Rectangular Area (DECRQCRA), VT420 and '
      'up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI Pm # P - XTPUSHCOLORS: Push current dynamic- and ANSI-palette colors onto stack, xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Pm # P - XTPUSHCOLORS: Push current dynamic- and '
      'ANSI-palette colors onto stack, xterm',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    r'CSI Pt ; Pl ; Pb ; Pr $ { - Selective Erase Rectangular Area (DECSERA), VT400 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Pt ; Pl ; Pb ; Pr $ { - Selective Erase '
      'Rectangular Area (DECSERA), VT400 and up.',
    ),
  );
  test(
    'CSI > Ps n - Disable key modifier options, xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI > Ps n - Disable key modifier options, xterm',
    ),
  );
  test(
    'CSI Ps i - MC: Media Copy',
    () => verifyInputHandlerIgnoredPlaywrightCase('CSI Ps i - MC: Media Copy'),
  );
  test(
    r'CSI Ps $ | - Select columns per page (DECSCPP), VT340.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Ps $ | - Select columns per page (DECSCPP), '
      'VT340.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI > Pm t - This xterm control sets one or more features of the title modes (XTSMTITLE), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI > Pm t - This xterm control sets one or more '
      'features of the title modes (XTSMTITLE), xterm.',
    ),
  );
  test(
    r'CSI Ps $ w - Request presentation state report (DECRQPSR), VT320 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Ps $ w - Request presentation state report '
      '(DECRQPSR), VT320 and up.',
    ),
  );
  test(
    'CSI Pl ; Pr s - Set left and right margins (DECSLRM), VT420 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Pl ; Pr s - Set left and right margins '
      '(DECSLRM), VT420 and up.',
    ),
  );
  test(
    "CSI Ps ; Pu ' z - Enable Locator Reporting (DECELR).",
    () => verifyInputHandlerIgnoredPlaywrightCase(
      "CSI Ps ; Pu ' z - Enable Locator Reporting (DECELR).",
    ),
  );
  test(
    r'CSI Ps $ ~ - Select status line type (DECSSDT), VT320 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Ps $ ~ - Select status line type (DECSSDT), '
      'VT320 and up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI ? Pm s - Save DEC Private Mode Values (XTSAVE), xterm.  Ps values are the same as for DECSET.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI ? Pm s - Save DEC Private Mode Values (XTSAVE), '
      'xterm.  Ps values are the same as for DECSET.',
    ),
  );
  test(
    'CSI [Pm] # { Push video attributes onto stack (XTPUSHSGR), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI [Pm] # { Push video attributes onto stack '
      '(XTPUSHSGR), xterm.',
    ),
  );
  test(
    'CSI ? Pp m - XTQMODKEYS: Query key modifier options, xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI ? Pp m - XTQMODKEYS: Query key modifier options, '
      'xterm',
    ),
  );
  test(
    'CSI Ps # y - Select checksum extension (XTCHECKSUM), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps # y - Select checksum extension (XTCHECKSUM), '
      'xterm.',
    ),
  );
  test(
    'CSI > Ps s - Set/reset shift-escape options (XTSHIFTESCAPE), xterm.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI > Ps s - Set/reset shift-escape options '
      '(XTSHIFTESCAPE), xterm.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI Pm # Q - XTPOPCOLORS: Pop stack to set dynamic- and ANSI-palette colors, xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Pm # Q - XTPOPCOLORS: Pop stack to set dynamic- '
      'and ANSI-palette colors, xterm',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    r'CSI Pt ; Pl ; Pb ; Pr ; Pm $ r - Change Attributes in Rectangular Area (DECCARA), VT400 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Pt ; Pl ; Pb ; Pr ; Pm $ r - Change Attributes '
      'in Rectangular Area (DECCARA), VT400 and up.',
    ),
  );
  test(
    'CSI Ps x - Request Terminal Parameters (DECREQTPARM).',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Ps x - Request Terminal Parameters '
      '(DECREQTPARM).',
    ),
  );
  test(
    'CSI Pl ; Pc " p - DECSCL: Set conformance level, VT220 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI Pl ; Pc " p - DECSCL: Set conformance level, '
      'VT220 and up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    r'CSI Pt ; Pl ; Pb ; Pr ; Pp ; Pt ; Pl ; Pp $ v - Copy Rectangular Area (DECCRA), VT400 and up.',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      r'CSI Pt ; Pl ; Pb ; Pr ; Pp ; Pt ; Pl ; Pp $ v - Copy '
      'Rectangular Area (DECCRA), VT400 and up.',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI # R - XTREPORTCOLORS: Report the current entry on the palette stack, and the number of palettes stored on the stack, using the same form as XTPOPCOLOR (default = 0), xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI # R - XTREPORTCOLORS: Report the current entry '
      'on the palette stack, and the number of palettes '
      'stored on the stack, using the same form as '
      'XTPOPCOLOR (default = 0), xterm',
    ),
  );
  test(
    'CSI > Ps p - XTSMPOINTER: Set resource value pointerMode, xterm',
    () => verifyInputHandlerIgnoredPlaywrightCase(
      'CSI > Ps p - XTSMPOINTER: Set resource value '
      'pointerMode, xterm',
    ),
  );
}
