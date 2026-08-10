## 0.1.0

- Initial release. Headless xterm-compatible VT/ANSI parsing extracted from
  `termworld`: the cell grid with scrollback and an alternate buffer, buffers
  and markers, selection state, keyboard and mouse encoding, Unicode width
  handling, and ANSI and HTML serialization of a live screen. Carries no
  renderer and no Flutter dependency, so a plain Dart server can mirror a
  pseudo-terminal and hand a reconnecting client the screen it left.
