import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('SharedRendererTests synchronized output', () {
    test('DOM synchronized output defers rendering until ESU', () async {
      await _defersRenderingUntilEsu();
    });

    test('WebGL synchronized output defers rendering until ESU', () async {
      await _defersRenderingUntilEsu();
    });

    test('DOM synchronized output batches multiple writes', () async {
      await _batchesMultipleWrites();
    });

    test('WebGL synchronized output batches multiple writes', () async {
      await _batchesMultipleWrites();
    });

    test('DOM synchronized output nested BSU is idempotent', () async {
      await _nestedBsuIsIdempotent();
    });

    test('WebGL synchronized output nested BSU is idempotent', () async {
      await _nestedBsuIsIdempotent();
    });

    test('DOM synchronized output timeout flushes without ESU', () async {
      await _timeoutFlushesWithoutEsu();
    });

    test('WebGL synchronized output timeout flushes without ESU', () async {
      await _timeoutFlushesWithoutEsu();
    });
  });
}

Future<void> _defersRenderingUntilEsu() async {
  final terminal = Terminal();
  final renders = <TerminalRenderEvent>[];
  final listener = terminal.onRender.listen(renders.add);
  addTearDown(listener.dispose);
  addTearDown(terminal.dispose);

  await terminal.writeAndWait('\x1b[?2026h');
  await terminal.writeAndWait('\x1b[31m■');
  expect(renders, isEmpty);
  expect(terminal.buffer.active.getLine(0)!.getCell(0)!.chars, '■');

  await terminal.writeAndWait('\x1b[?2026l');
  expect(renders, hasLength(1));
  expect(renders.single.start, 0);
  expect(renders.single.end, 0);
}

Future<void> _batchesMultipleWrites() async {
  final terminal = Terminal();
  final renders = <TerminalRenderEvent>[];
  final listener = terminal.onRender.listen(renders.add);
  addTearDown(listener.dispose);
  addTearDown(terminal.dispose);

  await terminal.writeAndWait('\x1b[?2026h');
  await terminal.writeAndWait('\x1b[31m■');
  await terminal.writeAndWait('\x1b[32m■');
  await terminal.writeAndWait('\x1b[34m■');
  expect(renders, isEmpty);

  await terminal.writeAndWait('\x1b[?2026l');
  expect(renders, hasLength(1));
  expect(
    terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
    '■■■',
  );
}

Future<void> _nestedBsuIsIdempotent() async {
  final terminal = Terminal();
  final renders = <TerminalRenderEvent>[];
  final listener = terminal.onRender.listen(renders.add);
  addTearDown(listener.dispose);
  addTearDown(terminal.dispose);

  await terminal.writeAndWait('\x1b[?2026h');
  await terminal.writeAndWait('\x1b[31m■');
  await terminal.writeAndWait('\x1b[?2026h');
  await terminal.writeAndWait('\x1b[32m■');
  expect(renders, isEmpty);

  await terminal.writeAndWait('\x1b[?2026l');
  expect(renders, hasLength(1));
  expect(
    terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
    '■■',
  );
}

Future<void> _timeoutFlushesWithoutEsu() async {
  final terminal = Terminal();
  final renders = <TerminalRenderEvent>[];
  final listener = terminal.onRender.listen(renders.add);
  addTearDown(listener.dispose);
  addTearDown(terminal.dispose);

  await terminal.writeAndWait('\x1b[?2026h');
  await terminal.writeAndWait('\x1b[31m■');
  await Future<void>.delayed(const Duration(milliseconds: 750));
  expect(renders, isEmpty);

  await _waitUntil(() => renders.isNotEmpty);
  expect(renders, hasLength(1));
  expect(terminal.modes.synchronizedOutputMode, isFalse);
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('synchronized output did not flush before the deadline');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
