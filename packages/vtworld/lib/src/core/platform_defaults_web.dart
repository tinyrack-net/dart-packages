import 'package:web/web.dart' as web;

String get _userAgent => web.window.navigator.userAgent;
String get _platform => web.window.navigator.platform;

/// Whether xterm's host-platform defaults should use macOS behavior.
bool get terminalHostIsMac =>
    <String>['Macintosh', 'MacIntel', 'MacPPC', 'Mac68K'].contains(_platform);

/// Whether this common runtime behaves like xterm's Node path.
bool get terminalHostIsNode => false;

/// Browser engine flags parsed exactly from xterm's user-agent checks.
bool get terminalHostIsFirefox => _userAgent.contains('Firefox');

/// Whether the user agent contains Chromium's marker.
bool get terminalHostIsChrome => _userAgent.contains('Chrome');

/// Whether the user agent contains legacy EdgeHTML's marker.
bool get terminalHostIsLegacyEdge => _userAgent.contains('Edge');

/// Whether the user agent matches Safari while excluding Chrome and Android.
bool get terminalHostIsSafari => RegExp(
  '^((?!chrome|android).)*safari',
  caseSensitive: false,
).hasMatch(_userAgent);

/// Host OS flags used by keyboard interpretation.
bool get terminalHostIsWindows =>
    <String>['Windows', 'Win16', 'Win32', 'WinCE'].contains(_platform);

/// Whether the browser platform contains Linux.
bool get terminalHostIsLinux => _platform.contains('Linux');

/// Whether the user agent identifies ChromeOS.
bool get terminalHostIsChromeOs => RegExp(r'\bCrOS\b').hasMatch(_userAgent);

/// Safari major version, or zero outside Safari.
int get terminalHostSafariVersion {
  if (!terminalHostIsSafari) return 0;
  final match = RegExp(r'Version/(\d+)').firstMatch(_userAgent);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

/// Xterm's common zoom factor is intentionally fixed at one.
double terminalHostZoomFactor(Object? _) => 1;
