import 'dart:io';

/// Whether xterm's host-platform defaults should use macOS behavior.
bool get terminalHostIsMac => Platform.isMacOS;

/// Whether this common runtime behaves like xterm's Node path.
bool get terminalHostIsNode => true;

/// Browser engine flags are false outside a browser.
bool get terminalHostIsFirefox => false;

/// Whether the runtime is Chromium-based.
bool get terminalHostIsChrome => false;

/// Whether the runtime is legacy EdgeHTML.
bool get terminalHostIsLegacyEdge => false;

/// Whether the runtime is Safari.
bool get terminalHostIsSafari => false;

/// Host OS flags used by keyboard interpretation.
bool get terminalHostIsWindows => Platform.isWindows;

/// Whether the host OS is Linux.
bool get terminalHostIsLinux => Platform.isLinux;

/// Whether the host is ChromeOS.
bool get terminalHostIsChromeOs => false;

/// Safari major version, or zero outside Safari.
int get terminalHostSafariVersion => 0;

/// Xterm's common zoom factor is intentionally fixed at one.
double terminalHostZoomFactor(Object? _) => 1;
