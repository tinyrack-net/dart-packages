# ptyworld

Cross-platform pseudo-terminal processes for Dart. `ptyworld` spawns a child
process attached to a real terminal — `openpty` on Linux and macOS, ConPTY on
Windows — and exposes it as a small typed API.

The package builds a C Native Asset through `hook/build.dart`, so no manual
build step or prebuilt binary is required. Linux, macOS, and Windows are
supported; Android and iOS receive no local PTY asset.

```dart
import 'package:ptyworld/ptyworld.dart';

final process = await PtyProcess.start('/bin/sh', columns: 100, rows: 40);
process.output.listen(stdout.add);

await process.write('echo hello\n'.codeUnits);
process.resize(columns: 120, rows: 50);

await process.terminate();
print(await process.exitCode);
```

## Design

- **Raw bytes, not text.** `output` is a `Stream<List<int>>`. A PTY can split a
  UTF-8 sequence or an escape sequence across reads, so decoding is stateful
  and belongs to the consumer along with terminal emulation.
- **Ordered, non-blocking writes.** `write` queues data and returns a future
  that completes once every byte has reached the terminal. Partial writes are
  resumed transparently and queue order is preserved.
- **Exact exit codes.** `exitCode` completes with the child's real status, and
  `terminate` escalates from a graceful signal to a forced one after a grace
  period, taking the whole process tree with it.

## Testing

```console
dart test
```

The suite drives real child processes. Branches that only occur when an
operating-system call fails — which a healthy terminal never does — are covered
by substituting `PtyBindings` through the `PtyProcess.withBindings` constructor.
