import 'package:test/test.dart';

import 'support/input_handler_osc_playwright_cases.dart';

void main() {
  test(
    'query single color',
    () => verifyInputHandlerOscPlaywrightCase('query single color'),
  );
  test(
    'restore full table',
    () => verifyInputHandlerOscPlaywrightCase('restore full table'),
  );
  test(
    'query FG color',
    () => verifyInputHandlerOscPlaywrightCase('query FG color'),
  );
  test(
    'set & query FG & BG color in one call',
    () => verifyInputHandlerOscPlaywrightCase(
      'set & query FG & BG color in one call',
    ),
  );
  test(
    'set & query cursor color',
    () => verifyInputHandlerOscPlaywrightCase('set & query cursor color'),
  );
  test(
    'set & query BG',
    () => verifyInputHandlerOscPlaywrightCase('set & query BG'),
  );
  test(
    'query multiple colors',
    () => verifyInputHandlerOscPlaywrightCase('query multiple colors'),
  );
  test(
    'change & restore single color',
    () => verifyInputHandlerOscPlaywrightCase('change & restore single color'),
  );
  test(
    'OSC 112: restore cursor color',
    () => verifyInputHandlerOscPlaywrightCase('OSC 112: restore cursor color'),
  );
  test(
    'query FG & BG color in one call',
    () =>
        verifyInputHandlerOscPlaywrightCase('query FG & BG color in one call'),
  );
  test(
    'set & query FG',
    () => verifyInputHandlerOscPlaywrightCase('set & query FG'),
  );
  test(
    'OSC 111: restore BG color',
    () => verifyInputHandlerOscPlaywrightCase('OSC 111: restore BG color'),
  );
  test(
    'restore multiple at once',
    () => verifyInputHandlerOscPlaywrightCase('restore multiple at once'),
  );
  test(
    'query & set colors mixed',
    () => verifyInputHandlerOscPlaywrightCase('query & set colors mixed'),
  );
  test(
    'OSC 110: restore FG color',
    () => verifyInputHandlerOscPlaywrightCase('OSC 110: restore FG color'),
  );
  test(
    'query BG color',
    () => verifyInputHandlerOscPlaywrightCase('query BG color'),
  );
  test(
    'set & query single color',
    () => verifyInputHandlerOscPlaywrightCase('set & query single color'),
  );
}
