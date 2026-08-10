import 'package:test/test.dart';

import 'support/input_handler_state_playwright_cases.dart';

void main() {
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'should save the absolute cursor position so resizing restores to the correct position',
    () => verifyInputHandlerStatePlaywrightCase(
      'should save the absolute cursor position so resizing '
      'restores to the correct position',
    ),
  );
  test(
    r'CSI ? Ps $ p - Request DEC private mode (DECRQM).',
    () => verifyInputHandlerStatePlaywrightCase(
      r'CSI ? Ps $ p - Request DEC private mode (DECRQM).',
    ),
  );
  test(
    r'CSI Ps $ p - DECRQM: Request ANSI mode',
    () => verifyInputHandlerStatePlaywrightCase(
      r'CSI Ps $ p - DECRQM: Request ANSI mode',
    ),
  );
  test(
    'CSI Ps h - SM: Set Mode',
    () => verifyInputHandlerStatePlaywrightCase('CSI Ps h - SM: Set Mode'),
  );
  test(
    'CSI u - Restore cursor (SCORC, also ANSI.SYS).',
    () => verifyInputHandlerStatePlaywrightCase(
      'CSI u - Restore cursor (SCORC, also ANSI.SYS).',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI Ps ; Ps r - Set Scrolling Region [top;bottom] (default = full size of window) (DECSTBM), VT100.',
    () => verifyInputHandlerStatePlaywrightCase(
      'CSI Ps ; Ps r - Set Scrolling Region [top;bottom] '
      '(default = full size of window) (DECSTBM), VT100.',
    ),
  );
  test(
    'CSI ! p - DECSTR: Soft terminal reset, VT220 and up.',
    () => verifyInputHandlerStatePlaywrightCase(
      'CSI ! p - DECSTR: Soft terminal reset, VT220 and up.',
    ),
  );
  test(
    'CSI Ps SP q - Set cursor style (DECSCUSR), VT520.',
    () => verifyInputHandlerStatePlaywrightCase(
      'CSI Ps SP q - Set cursor style (DECSCUSR), VT520.',
    ),
  );
  test(
    'CSI Ps " q - Select character protection attribute (DECSCA), VT220.',
    () => verifyInputHandlerStatePlaywrightCase(
      'CSI Ps " q - Select character protection attribute '
      '(DECSCA), VT220.',
    ),
  );
  test(
    'CSI Pm l - RM: Reset Mode',
    () => verifyInputHandlerStatePlaywrightCase('CSI Pm l - RM: Reset Mode'),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'CSI s - Save cursor, available only when DECLRMM is disabled (SCOSC, also ANSI.SYS).',
    () => verifyInputHandlerStatePlaywrightCase(
      'CSI s - Save cursor, available only when DECLRMM is '
      'disabled (SCOSC, also ANSI.SYS).',
    ),
  );
}
