# vtworld

Headless xterm-compatible terminal emulation for Dart.

`vtworld` turns pseudo-terminal output into a cell grid — scrollback, an
alternate buffer, DEC private modes, cursor state — and serializes that grid
back into ANSI that reproduces it in a reset terminal.

That second half is the point. A server that keeps only a raw byte log cannot
restore a session: the log is bounded, and trimming its front cuts the
alternate-screen entry and the initial full-screen paint off a long-lived
editor, leaving cursor-relative deltas with no anchor. A server that keeps a
parsed screen can hand any reconnecting client the screen itself.

```dart
import 'package:vtworld/vtworld.dart';

final terminal = Terminal(
  options: TerminalOptions(cols: 80, rows: 24, scrollback: 200),
);
final serialize = SerializeAddon();
terminal.loadAddon(serialize);

// Feed pseudo-terminal output as it arrives. Parsing is asynchronous because a
// custom sequence handler may be, so await when the grid has to correspond to
// a known point in the byte stream.
await terminal.writeAndWait(chunkFromPty);

// Hand a reconnecting client a screen instead of a byte log.
final ansi = serialize.serialize(
  options: const TerminalSerializeOptions(scrollback: 200),
);
```

The client resets its own terminal and writes `ansi`. If the session was inside
a full-screen program, the serialized form carries the alternate-buffer switch,
so the client genuinely enters the alternate buffer rather than being painted
with a picture of it — leaving that program afterwards uncovers the shell
history underneath, exactly as it would have on the original terminal.

## Relationship to termworld

`termworld` is the Flutter half: rendering, input, IME, selection gestures. It
depends on this package for parsing and re-exports its API, so a `Terminal` a
server feeds and a `Terminal` a widget renders are the same class.

The split is not stylistic. A server is a plain Dart program and cannot take a
Flutter SDK dependency, and rendering cannot be pulled into a package a server
links. `ptyworld`, in this repository, is the third piece: it spawns the
pseudo-terminal. It stays separate because it compiles C through a build hook
and supports only desktop platforms — folding a parser into it would make every
Android and web build of a Flutter consumer compile a native asset for a
pseudo-terminal that cannot exist there.

## Scope

Included: VT/ANSI parsing, the cell grid and scrollback, buffers and markers,
selection state, keyboard and mouse encoding, Unicode width handling, and ANSI
and HTML serialization.

Not included: any renderer, and the addons that only a renderer uses — search,
ligatures, images, WebGL, web links, web fonts.

## Status

Not published to pub.dev. Consumers pin it by commit SHA.
