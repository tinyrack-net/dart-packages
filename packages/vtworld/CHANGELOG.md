## 0.1.0

- Keeps a synchronous flush from abandoning queued output. `WriteBuffer`'s
  `flushSync` and `writeSync` drained the queue by calling the parser action
  directly, guarded only against reentrant synchronous writes. A chunk still
  awaiting an asynchronous handler was left unguarded, so a flush re-entered
  the parser, which refuses re-entry, threw `improper continuation due to
  previous async handler`, and dropped the chunk it was holding. Both now leave
  the queue to the pending write, which parses it in order once the handler
  resolves.
- Initial release. Headless xterm-compatible VT/ANSI parsing extracted from
  `termworld`: the cell grid with scrollback and an alternate buffer, buffers
  and markers, selection state, keyboard and mouse encoding, Unicode width
  handling, and ANSI and HTML serialization of a live screen. Carries no
  renderer and no Flutter dependency, so a plain Dart server can mirror a
  pseudo-terminal and hand a reconnecting client the screen it left.
