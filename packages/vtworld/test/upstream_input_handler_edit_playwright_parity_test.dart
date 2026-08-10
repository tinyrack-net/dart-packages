import 'package:test/test.dart';

import 'support/input_handler_edit_playwright_cases.dart';

void main() {
  test(
    'CSI Ps T - SD: Scroll down Ps lines (default = 1), VT420',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps T - SD: Scroll down Ps lines (default = 1), '
      'VT420',
    ),
  );
  test(
    'CSI Ps M - DL: Delete Ps Line(s) (default = 1)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps M - DL: Delete Ps Line(s) (default = 1)',
    ),
  );
  test(
    'CSI Ps L - IL: Insert Ps Line(s) (default = 1)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps L - IL: Insert Ps Line(s) (default = 1)',
    ),
  );
  test(
    'CSI ? Ps K - DECSEL: Erase in Line, VT220',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI ? Ps K - DECSEL: Erase in Line, VT220',
    ),
  );
  test(
    'CSI Ps Z - CBT: Cursor Backward Tabulation Ps tab stops (default = 1)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps Z - CBT: Cursor Backward Tabulation Ps tab '
      'stops (default = 1)',
    ),
  );
  test(
    'CSI Ps S - SU: Scroll up Ps lines (default = 1), VT420, ECMA-48',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps S - SU: Scroll up Ps lines (default = 1), '
      'VT420, ECMA-48',
    ),
  );
  test(
    'CSI Ps J - ED: Erase in Display, VT100',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps J - ED: Erase in Display, VT100',
    ),
  );
  test(
    'CSI Ps K - EL: Erase in Line, VT100',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps K - EL: Erase in Line, VT100',
    ),
  );
  test(
    'CSI Ps ^ - SD: Scroll down Ps lines (default = 1) (SD), ECMA-48',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps ^ - SD: Scroll down Ps lines (default = 1) '
      '(SD), ECMA-48',
    ),
  );
  test(
    'CSI Ps P - DCH: Delete Ps Character(s) (default = 1)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps P - DCH: Delete Ps Character(s) (default = 1)',
    ),
  );
  test(
    'CSI Ps X - ECH: Erase Ps Character(s) (default = 1)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps X - ECH: Erase Ps Character(s) (default = 1)',
    ),
  );
  test(
    'CSI Ps b - REP: Repeat preceding character, ECMA48',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps b - REP: Repeat preceding character, ECMA48',
    ),
  );
  test(
    'CSI ? Ps J - DECSED: Erase in Display, VT220',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI ? Ps J - DECSED: Erase in Display, VT220',
    ),
  );
  test(
    'CSI Ps SP @ - SL: Shift left Ps columns(s) (default = 1), ECMA-48',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps SP @ - SL: Shift left Ps columns(s) (default '
      '= 1), ECMA-48',
    ),
  );
  test(
    'CSI Ps g - TBC: Tab Clear (default = 0)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps g - TBC: Tab Clear (default = 0)',
    ),
  );
  test(
    'CSI Ps I - CHT: Cursor Forward Tabulation Ps tab stops (default = 1)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps I - CHT: Cursor Forward Tabulation Ps tab '
      'stops (default = 1)',
    ),
  );
  test(
    'CSI Ps @ - ICH: Insert Ps (Blank) Character(s) (default = 1)',
    () => verifyInputHandlerEditPlaywrightCase(
      'CSI Ps @ - ICH: Insert Ps (Blank) Character(s) '
      '(default = 1)',
    ),
  );
}
