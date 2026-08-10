import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm MouseTracking X10 default', () async {
    await _verifyTracking(mode: 9, sgr: false, kind: _TrackingKind.x10);
  });
  test('xterm MouseTracking X10 SGR', () async {
    await _verifyTracking(mode: 9, sgr: true, kind: _TrackingKind.x10);
  });
  test('xterm MouseTracking VT200 default', () async {
    await _verifyTracking(mode: 1000, sgr: false, kind: _TrackingKind.vt200);
  });
  test('xterm MouseTracking VT200 SGR', () async {
    await _verifyTracking(mode: 1000, sgr: true, kind: _TrackingKind.vt200);
  });
  test('xterm MouseTracking drag default', () async {
    await _verifyTracking(mode: 1002, sgr: false, kind: _TrackingKind.drag);
  });
  test('xterm MouseTracking drag SGR', () async {
    await _verifyTracking(mode: 1002, sgr: true, kind: _TrackingKind.drag);
  });
  test('xterm MouseTracking any default', () async {
    await _verifyTracking(mode: 1003, sgr: false, kind: _TrackingKind.any);
  });
  test('xterm MouseTracking any SGR', () async {
    await _verifyTracking(mode: 1003, sgr: true, kind: _TrackingKind.any);
  });
}

enum _TrackingKind { x10, vt200, drag, any }

Future<void> _verifyTracking({
  required int mode,
  required bool sgr,
  required _TrackingKind kind,
}) async {
  final terminal = Terminal(options: TerminalOptions(cols: 260, rows: 50));
  addTearDown(terminal.dispose);
  final reports = <String>[];
  terminal.onBinary.listen(reports.add);
  terminal.onData.listen(reports.add);
  await terminal.writeAndWait(
    '\u001b[?9l\u001b[?1000l\u001b[?1002l\u001b[?1003l'
    '\u001b[?1006${sgr ? 'h' : 'l'}\u001b[?$mode'
    'h',
  );

  final down = _event(
    column: 43,
    row: 24,
    button: TerminalMouseButton.left,
    action: TerminalMouseAction.down,
  );
  expect(terminal.reportMouseEvent(down), isTrue);
  expect(reports.removeAt(0), _encoded(sgr, 0, 44, 25, release: false));

  final move = _event(
    column: 44,
    row: 24,
    button: TerminalMouseButton.left,
    action: TerminalMouseAction.move,
  );
  final reportsDrag = kind == _TrackingKind.drag || kind == _TrackingKind.any;
  expect(terminal.reportMouseEvent(move), reportsDrag);
  if (reportsDrag) {
    expect(reports.removeAt(0), _encoded(sgr, 32, 45, 25, release: false));
  }

  final up = _event(
    column: 44,
    row: 24,
    button: TerminalMouseButton.left,
    action: TerminalMouseAction.up,
  );
  final reportsRelease = kind != _TrackingKind.x10;
  expect(terminal.reportMouseEvent(up), reportsRelease);
  if (reportsRelease) {
    expect(
      reports.removeAt(0),
      _encoded(sgr, sgr ? 0 : 3, 45, 25, release: true),
    );
  }

  final hover = _event(
    column: 45,
    row: 25,
    button: TerminalMouseButton.none,
    action: TerminalMouseAction.move,
  );
  final reportsHover = kind == _TrackingKind.any;
  expect(terminal.reportMouseEvent(hover), reportsHover);
  if (reportsHover) {
    expect(reports.removeAt(0), _encoded(sgr, 35, 46, 26, release: false));
  }

  reports.clear();
  expect(
    terminal.reportMouseEvent(
      _event(
        column: 0,
        row: 0,
        button: TerminalMouseButton.left,
        action: TerminalMouseAction.down,
        control: true,
        alt: true,
        shift: true,
      ),
    ),
    isTrue,
  );
  final modifierCode = kind == _TrackingKind.x10 ? 0 : 28;
  expect(reports.single, _encoded(sgr, modifierCode, 1, 1, release: false));

  if (!sgr) {
    reports.clear();
    expect(
      terminal.reportMouseEvent(
        _event(
          column: 223,
          row: 0,
          button: TerminalMouseButton.left,
          action: TerminalMouseAction.down,
        ),
      ),
      isTrue,
    );
    expect(reports, isEmpty);
  }
}

TerminalMouseEvent _event({
  required int column,
  required int row,
  required TerminalMouseButton button,
  required TerminalMouseAction action,
  bool shift = false,
  bool alt = false,
  bool control = false,
}) => TerminalMouseEvent(
  column: column,
  row: row,
  pixelX: column * 6 + 2,
  pixelY: row * 12 + 2,
  button: button,
  action: action,
  shift: shift,
  alt: alt,
  control: control,
);

String _encoded(
  bool sgr,
  int code,
  int column,
  int row, {
  required bool release,
}) {
  if (sgr) return '\u001b[<$code;$column;$row${release ? 'm' : 'M'}';
  final payload = String.fromCharCodes(<int>[code + 32, column + 32, row + 32]);
  return '\u001b[M$payload';
}
