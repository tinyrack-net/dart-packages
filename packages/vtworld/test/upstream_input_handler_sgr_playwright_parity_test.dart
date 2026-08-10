import 'package:test/test.dart';

import 'support/input_handler_sgr_playwright_cases.dart';

void main() {
  test(
    'Ps = 0 - Normal (default), VT100',
    () =>
        verifyInputHandlerSgrPlaywrightCase('Ps = 0 - Normal (default), VT100'),
  );
  test(
    'Ps = 1 - Bold, VT100',
    () => verifyInputHandlerSgrPlaywrightCase('Ps = 1 - Bold, VT100'),
  );
  test(
    'Ps = 100 - Set background color to bright Black',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 100 - Set background color to bright Black',
    ),
  );
  test(
    'Ps = 101 - Set background color to bright Red',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 101 - Set background color to bright Red',
    ),
  );
  test(
    'Ps = 102 - Set background color to bright Green',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 102 - Set background color to bright Green',
    ),
  );
  test(
    'Ps = 103 - Set background color to bright Yellow',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 103 - Set background color to bright Yellow',
    ),
  );
  test(
    'Ps = 104 - Set background color to bright Blue',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 104 - Set background color to bright Blue',
    ),
  );
  test(
    'Ps = 105 - Set background color to bright Magenta',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 105 - Set background color to bright Magenta',
    ),
  );
  test(
    'Ps = 106 - Set background color to bright Cyan',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 106 - Set background color to bright Cyan',
    ),
  );
  test(
    'Ps = 107 - Set background color to bright White',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 107 - Set background color to bright White',
    ),
  );
  test(
    'Ps = 2 - Faint, decreased intensity, ECMA-48 2nd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 2 - Faint, decreased intensity, ECMA-48 2nd',
    ),
  );
  test(
    'Ps = 21 - Doubly-underlined, ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 21 - Doubly-underlined, ECMA-48 3rd',
    ),
  );
  test(
    'Ps = 22 - Normal (neither bold nor faint), ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 22 - Normal (neither bold nor faint), ECMA-48 '
      '3rd',
    ),
  );
  test(
    'Ps = 23 - Not italicized, ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 23 - Not italicized, ECMA-48 3rd',
    ),
  );
  test(
    'Ps = 24 - Not underlined, ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 24 - Not underlined, ECMA-48 3rd',
    ),
  );
  test(
    'Ps = 25 - Steady (not blinking), ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 25 - Steady (not blinking), ECMA-48 3rd',
    ),
  );
  test(
    'Ps = 27 - Positive (not inverse), ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 27 - Positive (not inverse), ECMA-48 3rd',
    ),
  );
  test(
    'Ps = 28 - Visible, ECMA-48 3rd, VT300',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 28 - Visible, ECMA-48 3rd, VT300',
    ),
  );
  test(
    'Ps = 29 - Not crossed-out, ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 29 - Not crossed-out, ECMA-48 3rd',
    ),
  );
  test(
    'Ps = 3 - Italicized, ECMA-48 2nd',
    () =>
        verifyInputHandlerSgrPlaywrightCase('Ps = 3 - Italicized, ECMA-48 2nd'),
  );
  test(
    'Ps = 30 - Set foreground color to Black',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 30 - Set foreground color to Black',
    ),
  );
  test(
    'Ps = 31 - Set foreground color to Red',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 31 - Set foreground color to Red',
    ),
  );
  test(
    'Ps = 32 - Set foreground color to Green',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 32 - Set foreground color to Green',
    ),
  );
  test(
    'Ps = 33 - Set foreground color to Yellow',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 33 - Set foreground color to Yellow',
    ),
  );
  test(
    'Ps = 34 - Set foreground color to Blue',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 34 - Set foreground color to Blue',
    ),
  );
  test(
    'Ps = 35 - Set foreground color to Magenta',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 35 - Set foreground color to Magenta',
    ),
  );
  test(
    'Ps = 36 - Set foreground color to Cyan',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 36 - Set foreground color to Cyan',
    ),
  );
  test(
    'Ps = 37 - Set foreground color to White',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 37 - Set foreground color to White',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 38:2:Pi:Pr:Pg:Pb - Set foreground color using RGB values (colon separator)',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 38:2:Pi:Pr:Pg:Pb - Set foreground color using '
      'RGB values (colon separator)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 38:5:Ps - Set foreground color to Ps using indexed color (colon separator)',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 38:5:Ps - Set foreground color to Ps using '
      'indexed color (colon separator)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 38;2;Pr;Pg;Pb - Set foreground color using RGB values (semicolon separator)',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 38;2;Pr;Pg;Pb - Set foreground color using RGB '
      'values (semicolon separator)',
    ),
  );
  test(
    'Ps = 39 - Set foreground color to default, ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 39 - Set foreground color to default, ECMA-48 '
      '3rd',
    ),
  );
  test(
    'Ps = 4 - Underlined, VT100',
    () => verifyInputHandlerSgrPlaywrightCase('Ps = 4 - Underlined, VT100'),
  );
  test(
    'Ps = 40 - Set background color to Black',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 40 - Set background color to Black',
    ),
  );
  test(
    'Ps = 41 - Set background color to Red',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 41 - Set background color to Red',
    ),
  );
  test(
    'Ps = 42 - Set background color to Green',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 42 - Set background color to Green',
    ),
  );
  test(
    'Ps = 43 - Set background color to Yellow',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 43 - Set background color to Yellow',
    ),
  );
  test(
    'Ps = 44 - Set background color to Blue',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 44 - Set background color to Blue',
    ),
  );
  test(
    'Ps = 45 - Set background color to Magenta',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 45 - Set background color to Magenta',
    ),
  );
  test(
    'Ps = 46 - Set background color to Cyan',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 46 - Set background color to Cyan',
    ),
  );
  test(
    'Ps = 47 - Set background color to White',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 47 - Set background color to White',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 48:2:Pi:Pr:Pg:Pb - Set background color using RGB values (colon separator)',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 48:2:Pi:Pr:Pg:Pb - Set background color using '
      'RGB values (colon separator)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 48:5:Ps - Set background color to Ps using indexed color (colon separator)',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 48:5:Ps - Set background color to Ps using '
      'indexed color (colon separator)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Ps = 48;2;Pr;Pg;Pb - Set background color using RGB values (semicolon separator)',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 48;2;Pr;Pg;Pb - Set background color using RGB '
      'values (semicolon separator)',
    ),
  );
  test(
    'Ps = 49 - Set background color to default, ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 49 - Set background color to default, ECMA-48 '
      '3rd',
    ),
  );
  test(
    'Ps = 5 - Blink, VT100',
    () => verifyInputHandlerSgrPlaywrightCase('Ps = 5 - Blink, VT100'),
  );
  test(
    'Ps = 7 - Inverse, VT100',
    () => verifyInputHandlerSgrPlaywrightCase('Ps = 7 - Inverse, VT100'),
  );
  test(
    'Ps = 8 - Invisible, ECMA-48 2nd, VT300',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 8 - Invisible, ECMA-48 2nd, VT300',
    ),
  );
  test(
    'Ps = 9 - Crossed-out characters, ECMA-48 3rd',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 9 - Crossed-out characters, ECMA-48 3rd',
    ),
  );
  test(
    'Ps = 90 - Set foreground color to bright Black',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 90 - Set foreground color to bright Black',
    ),
  );
  test(
    'Ps = 91 - Set foreground color to bright Red',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 91 - Set foreground color to bright Red',
    ),
  );
  test(
    'Ps = 92 - Set foreground color to bright Green',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 92 - Set foreground color to bright Green',
    ),
  );
  test(
    'Ps = 93 - Set foreground color to bright Yellow',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 93 - Set foreground color to bright Yellow',
    ),
  );
  test(
    'Ps = 94 - Set foreground color to bright Blue',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 94 - Set foreground color to bright Blue',
    ),
  );
  test(
    'Ps = 95 - Set foreground color to bright Magenta',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 95 - Set foreground color to bright Magenta',
    ),
  );
  test(
    'Ps = 96 - Set foreground color to bright Cyan',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 96 - Set foreground color to bright Cyan',
    ),
  );
  test(
    'Ps = 97 - Set foreground color to bright White',
    () => verifyInputHandlerSgrPlaywrightCase(
      'Ps = 97 - Set foreground color to bright White',
    ),
  );
}
