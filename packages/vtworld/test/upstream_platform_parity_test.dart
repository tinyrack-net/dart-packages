import 'package:test/test.dart';
import 'package:vtworld/src/core/platform_defaults.dart';

void main() {
  test('common platform flags remain internally consistent', () {
    expect(terminalHostZoomFactor(null), 1);
    expect(terminalHostSafariVersion, greaterThanOrEqualTo(0));
    if (terminalHostIsNode) {
      expect(<bool>[
        terminalHostIsFirefox,
        terminalHostIsChrome,
        terminalHostIsLegacyEdge,
        terminalHostIsSafari,
        terminalHostIsChromeOs,
      ], everyElement(isFalse));
    }
    expect(
      <bool>[
        terminalHostIsMac,
        terminalHostIsWindows,
        terminalHostIsLinux,
      ].where((value) => value).length,
      lessThanOrEqualTo(1),
    );
  });
}
