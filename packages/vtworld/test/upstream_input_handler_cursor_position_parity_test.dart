import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler cursor positioning', () {
    test('cursor forward (CUF)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[C', 1, 0),
        const _Step('\x1b[1C', 2, 0),
        const _Step('\x1b[4C', 6, 0),
        const _Step('\x1b[100C', 9, 0),
        const _Step('\x1b[5;9H\x1b[C', 9, 4),
      ]);
    });
    test('cursor backward (CUB)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[D', 0, 0),
        const _Step('\x1b[1D', 0, 0),
        const _Step('\x1b[100C\x1b[D', 8, 0),
        const _Step('\x1b[1D', 7, 0),
        const _Step('\x1b[4D', 3, 0),
        const _Step('\x1b[100D', 0, 0),
        const _Step('\x1b[5;5H\x1b[D', 3, 4),
      ]);
    });
    test('cursor down (CUD)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[B', 0, 1),
        const _Step('\x1b[1B', 0, 2),
        const _Step('\x1b[4B', 0, 6),
        const _Step('\x1b[100B', 0, 9),
        const _Step('\x1b[1;9H\x1b[B', 8, 1),
      ]);
    });
    test('cursor up (CUU)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[A', 0, 0),
        const _Step('\x1b[1A', 0, 0),
        const _Step('\x1b[100B\x1b[A', 0, 8),
        const _Step('\x1b[1A', 0, 7),
        const _Step('\x1b[4A', 0, 3),
        const _Step('\x1b[100A', 0, 0),
        const _Step('\x1b[10;9H\x1b[A', 8, 8),
      ]);
    });
    test('cursor next line (CNL)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[E', 0, 1),
        const _Step('\x1b[1E', 0, 2),
        const _Step('\x1b[4E', 0, 6),
        const _Step('\x1b[100E', 0, 9),
        const _Step('\x1b[1;9H\x1b[E', 0, 1),
      ]);
    });
    test('cursor previous line (CPL)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[F', 0, 0),
        const _Step('\x1b[1F', 0, 0),
        const _Step('\x1b[100E\x1b[F', 0, 8),
        const _Step('\x1b[1F', 0, 7),
        const _Step('\x1b[4F', 0, 3),
        const _Step('\x1b[100F', 0, 0),
        const _Step('\x1b[10;9H\x1b[F', 0, 8),
      ]);
    });
    test('cursor character absolute (CHA)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[G', 0, 0),
        const _Step('\x1b[1G', 0, 0),
        const _Step('\x1b[2G', 1, 0),
        const _Step('\x1b[5G', 4, 0),
        const _Step('\x1b[100G', 9, 0),
      ]);
    });
    test('cursor position (CUP)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[6;6H\x1b[H', 0, 0),
        const _Step('\x1b[6;6H\x1b[1H', 0, 0),
        const _Step('\x1b[6;6H\x1b[1;1H', 0, 0),
        const _Step('\x1b[6;6H\x1b[8H', 0, 7),
        const _Step('\x1b[6;6H\x1b[;8H', 7, 0),
        const _Step('\x1b[100;100H', 9, 9),
      ]);
    });
    test('cursor position (CUP) with DECOM and scroll margins', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[?6h\x1b[2;3r\x1b[1;1H');
      _expectCursor(terminal, 0, 1);
      await terminal.writeAndWait('X\x1b[2;1H');
      _expectCursor(terminal, 0, 2);
      expect(_line(terminal, 1), 'X');
      await terminal.writeAndWait('\x1b[10;10H');
      _expectCursor(terminal, 9, 2);
      await terminal.writeAndWait('\x1b[?6l\x1b[2;1H');
      _expectCursor(terminal, 0, 1);
    });
    test('horizontal position absolute (HPA)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[`', 0, 0),
        const _Step('\x1b[1`', 0, 0),
        const _Step('\x1b[2`', 1, 0),
        const _Step('\x1b[5`', 4, 0),
        const _Step('\x1b[100`', 9, 0),
      ]);
    });
    test('horizontal position relative (HPR)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[a', 1, 0),
        const _Step('\x1b[1a', 2, 0),
        const _Step('\x1b[4a', 6, 0),
        const _Step('\x1b[100a', 9, 0),
        const _Step('\x1b[5;9H\x1b[a', 9, 4),
      ]);
    });
    test('vertical position absolute (VPA)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[d', 0, 0),
        const _Step('\x1b[1d', 0, 0),
        const _Step('\x1b[2d', 0, 1),
        const _Step('\x1b[5d', 0, 4),
        const _Step('\x1b[100d', 0, 9),
        const _Step('\x1b[5;9H\x1b[d', 8, 0),
      ]);
    });
    test('vertical position relative (VPR)', () async {
      await _steps(<_Step>[
        const _Step('\x1b[e', 0, 1),
        const _Step('\x1b[1e', 0, 2),
        const _Step('\x1b[4e', 0, 6),
        const _Step('\x1b[100e', 0, 9),
        const _Step('\x1b[5;9H\x1b[e', 8, 5),
      ]);
    });
  });
}

final class _Step {
  const _Step(this.sequence, this.x, this.y);
  final String sequence;
  final int x;
  final int y;
}

Future<void> _steps(List<_Step> steps) async {
  final terminal = _terminal();
  try {
    for (final step in steps) {
      await terminal.writeAndWait(step.sequence);
      _expectCursor(terminal, step.x, step.y);
    }
  } finally {
    terminal.dispose();
  }
}

Terminal _terminal() => Terminal(options: TerminalOptions(cols: 10, rows: 10));

void _expectCursor(Terminal terminal, int x, int y) {
  expect(terminal.buffer.active.cursorX, x);
  expect(terminal.buffer.active.cursorY, y);
}

String _line(Terminal terminal, int row) =>
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true);
