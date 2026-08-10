import 'package:test/test.dart';

import 'support/input_handler_report_playwright_cases.dart';

void main() {
  test(
    'should be disabled by default',
    () =>
        verifyInputHandlerReportPlaywrightCase('should be disabled by default'),
  );
  test(
    'CSI > Ps c - ',
    () => verifyInputHandlerReportPlaywrightCase('CSI > Ps c - '),
  );
  test(
    'CSI > Ps q - Report xterm name and version (XTVERSION).',
    () => verifyInputHandlerReportPlaywrightCase(
      'CSI > Ps q - Report xterm name and version (XTVERSION).',
    ),
  );
  test(
    '14 - GetWinSizePixels',
    () => verifyInputHandlerReportPlaywrightCase('14 - GetWinSizePixels'),
  );
  test(
    'Report Cursor Position (CPR) - CSI 6 n',
    () => verifyInputHandlerReportPlaywrightCase(
      'Report Cursor Position (CPR) - CSI 6 n',
    ),
  );
  test(
    'Color Scheme Query - CSI ? 996 n (light theme)',
    () => verifyInputHandlerReportPlaywrightCase(
      'Color Scheme Query - CSI ? 996 n (light theme)',
    ),
  );
  test(
    'Report Cursor Position (DECXCPR) - CSI ? 6 n',
    () => verifyInputHandlerReportPlaywrightCase(
      'Report Cursor Position (DECXCPR) - CSI ? 6 n',
    ),
  );
  test(
    'CSI = Ps c - ',
    () => verifyInputHandlerReportPlaywrightCase('CSI = Ps c - '),
  );
  test(
    'CSI Ps c - ',
    () => verifyInputHandlerReportPlaywrightCase('CSI Ps c - '),
  );
  test(
    '16 - GetCellSizePixels',
    () => verifyInputHandlerReportPlaywrightCase('16 - GetCellSizePixels'),
  );
  test(
    'Status Report - CSI 5 n',
    () => verifyInputHandlerReportPlaywrightCase('Status Report - CSI 5 n'),
  );
  test(
    'Color Scheme Query disabled via vtExtensions.colorSchemeQuery',
    () => verifyInputHandlerReportPlaywrightCase(
      'Color Scheme Query disabled via vtExtensions.colorSchemeQuery',
    ),
  );
  test(
    'Color Scheme Query - CSI ? 996 n (dark theme)',
    () => verifyInputHandlerReportPlaywrightCase(
      'Color Scheme Query - CSI ? 996 n (dark theme)',
    ),
  );
}
