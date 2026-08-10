import 'package:test/test.dart';

import 'support/input_handler_cursor_playwright_cases.dart';

void main() {
  test(
    'CSI Ps a - HPR: Character Position Relative (default = [row,col+1])',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps a - HPR: Character Position Relative (default '
      '= [row,col+1])',
    ),
  );
  test(
    'CSI Ps C - CUF: Cursor Forward Ps Times (default = 1)',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps C - CUF: Cursor Forward Ps Times (default = '
      '1)',
    ),
  );
  test(
    'CSI Ps A - CUU: Cursor Up Ps Times (default = 1)',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps A - CUU: Cursor Up Ps Times (default = 1)',
    ),
  );
  test(
    'CSI Ps e - VPR: Line Position Relative (default = 1)',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps e - VPR: Line Position Relative (default = 1)',
    ),
  );
  test(
    'CSI Ps d - VPA: Line Position Absolute [row] (default = [1,column])',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps d - VPA: Line Position Absolute [row] '
      '(default = [1,column])',
    ),
  );
  test(
    'CSI Ps ; Ps H - CUP: Cursor Position [row;column] (default = [1,1])',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps ; Ps H - CUP: Cursor Position [row;column] '
      '(default = [1,1])',
    ),
  );
  test(
    'CSI Ps G - CHA: Cursor Character Absolute [column] (default = [row,1])',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps G - CHA: Cursor Character Absolute [column] '
      '(default = [row,1])',
    ),
  );
  test(
    'CSI Ps B - CUD: Cursor Down Ps Times (default = 1)',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps B - CUD: Cursor Down Ps Times (default = 1)',
    ),
  );
  test(
    'CSI Ps ` - HPA: Character Position Absolute [column] (default = [row,1])',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps ` - HPA: Character Position Absolute [column] '
      '(default = [row,1])',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'CSI Ps ; Ps f - HVP: Horizontal and Vertical Position [row;column] (default = [1,1])',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps ; Ps f - HVP: Horizontal and Vertical '
      'Position [row;column] (default = [1,1])',
    ),
  );
  test(
    'CSI Ps D - CUB: Cursor Backward Ps Times (default = 1)',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps D - CUB: Cursor Backward Ps Times (default = '
      '1)',
    ),
  );
  test(
    'CSI Ps F - CPL: Cursor Preceding Line Ps Times (default = 1)',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps F - CPL: Cursor Preceding Line Ps Times '
      '(default = 1)',
    ),
  );
  test(
    'CSI Ps E - CNL: Cursor Next Line Ps Times (default = 1)',
    () => verifyInputHandlerCursorPlaywrightCase(
      'CSI Ps E - CNL: Cursor Next Line Ps Times (default = '
      '1)',
    ),
  );
}
