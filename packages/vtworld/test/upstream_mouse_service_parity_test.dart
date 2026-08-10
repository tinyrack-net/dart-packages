import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm MouseService 00', () async {
    final terminal = await _terminalForMode(1003);
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.up),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.move),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.middle, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.right, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.wheel, TerminalMouseAction.up),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.none, TerminalMouseAction.move),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.wheel, TerminalMouseAction.move),
      isFalse,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.none, TerminalMouseAction.down),
      isFalse,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.none, TerminalMouseAction.up),
      isFalse,
    );
    expect(_triggerAt(terminal, -1, 0), isFalse);
    expect(_triggerAt(terminal, 500, 0), isFalse);
    expect(_triggerAt(terminal, 0, -1), isFalse);
    expect(_triggerAt(terminal, 0, 500), isFalse);
  });

  test('xterm MouseService 01', () async {
    final terminal = await _terminalForMode(1002);
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.up),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.move),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.middle, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.right, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.wheel, TerminalMouseAction.up),
      isTrue,
    );
  });

  test('xterm MouseService 02', () {
    final terminal = Terminal(options: TerminalOptions(cols: 500, rows: 500));
    addTearDown(terminal.dispose);
    for (final event in _standardEvents) {
      expect(terminal.reportMouseEvent(event), isFalse);
    }
  });

  test('xterm MouseService 03', () async {
    final terminal = await _terminalForMode(1000);
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.up),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.move),
      isFalse,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.middle, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.right, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.wheel, TerminalMouseAction.up),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.none, TerminalMouseAction.move),
      isFalse,
    );
  });

  test('xterm MouseService 04', () async {
    final terminal = await _terminalForMode(9);
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.up),
      isFalse,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.left, TerminalMouseAction.move),
      isFalse,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.middle, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.right, TerminalMouseAction.down),
      isTrue,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.wheel, TerminalMouseAction.up),
      isFalse,
    );
    expect(
      _trigger(terminal, TerminalMouseButton.none, TerminalMouseAction.move),
      isFalse,
    );
  });

  test('xterm MouseService 05', () async {
    final terminal = await _terminalForMode(1003);
    final reports = <String>[];
    terminal.onBinary.listen(reports.add);
    for (var column = 0; column < 500; column++) {
      expect(_triggerAt(terminal, column, 0), isTrue);
      if (column > 222) {
        expect(reports, isEmpty);
      } else {
        expect(reports.removeLast().codeUnits, <int>[
          0x1b,
          0x5b,
          0x4d,
          0x20,
          column + 33,
          0x21,
        ]);
      }
    }
  });

  test('xterm MouseService 06', () async {
    final terminal = await _terminalForMode(1003, encodingMode: 1006);
    final reports = <String>[];
    terminal.onData.listen(reports.add);
    for (var column = 0; column < 500; column++) {
      expect(_triggerAt(terminal, column, 0), isTrue);
      expect(reports.removeLast(), '\u001b[<0;${column + 1};1M');
    }
  });

  test('xterm MouseService 07', () async {
    final terminal = await _terminalForMode(1003, encodingMode: 1016);
    final reports = <String>[];
    terminal.onData.listen(reports.add);
    for (var pixel = 0; pixel < 500; pixel++) {
      expect(
        terminal.reportMouseEvent(
          TerminalMouseEvent(
            column: 0,
            row: 0,
            pixelX: pixel,
            pixelY: 0,
            button: TerminalMouseButton.left,
            action: TerminalMouseAction.down,
          ),
        ),
        isTrue,
      );
      expect(reports.removeLast(), '\u001b[<0;$pixel;0M');
    }
  });

  test('xterm MouseService 08', () async {
    final terminal = await _terminalForMode(1003);
    final reports = <String>[];
    terminal.onBinary.listen(reports.add);
    for (final event in <TerminalMouseEvent>[
      _event(TerminalMouseButton.left, TerminalMouseAction.down),
      _event(TerminalMouseButton.middle, TerminalMouseAction.down),
      _event(TerminalMouseButton.right, TerminalMouseAction.down),
      _event(TerminalMouseButton.wheel, TerminalMouseAction.down),
    ]) {
      expect(terminal.reportMouseEvent(event), isTrue);
    }
    expect(reports, <String>[
      '\u001b[M !!',
      '\u001b[M!!!',
      '\u001b[M"!!',
      '\u001b[Ma!!',
    ]);
    reports.clear();
    for (final event in <TerminalMouseEvent>[
      _event(TerminalMouseButton.left, TerminalMouseAction.up),
      _event(TerminalMouseButton.middle, TerminalMouseAction.up),
      _event(TerminalMouseButton.right, TerminalMouseAction.up),
      _event(TerminalMouseButton.wheel, TerminalMouseAction.up),
    ]) {
      expect(terminal.reportMouseEvent(event), isTrue);
    }
    expect(reports, <String>[
      '\u001b[M#!!',
      '\u001b[M#!!',
      '\u001b[M#!!',
      '\u001b[M`!!',
    ]);
    reports.clear();
    for (final event in <TerminalMouseEvent>[
      _event(TerminalMouseButton.left, TerminalMouseAction.move),
      _event(TerminalMouseButton.middle, TerminalMouseAction.move),
      _event(TerminalMouseButton.right, TerminalMouseAction.move),
      _event(TerminalMouseButton.none, TerminalMouseAction.move),
    ]) {
      expect(terminal.reportMouseEvent(event), isTrue);
    }
    expect(reports, <String>[
      '\u001b[M@!!',
      '\u001b[MA!!',
      '\u001b[MB!!',
      '\u001b[MC!!',
    ]);
    reports.clear();
    for (final event in <TerminalMouseEvent>[
      _event(TerminalMouseButton.none, TerminalMouseAction.move, control: true),
      _event(TerminalMouseButton.none, TerminalMouseAction.move, alt: true),
      _event(TerminalMouseButton.none, TerminalMouseAction.move, shift: true),
      _event(
        TerminalMouseButton.none,
        TerminalMouseAction.move,
        control: true,
        alt: true,
      ),
      _event(
        TerminalMouseButton.none,
        TerminalMouseAction.move,
        alt: true,
        shift: true,
      ),
      _event(
        TerminalMouseButton.none,
        TerminalMouseAction.move,
        control: true,
        alt: true,
        shift: true,
      ),
    ]) {
      expect(terminal.reportMouseEvent(event), isTrue);
    }
    expect(reports, <String>[
      '\u001b[MS!!',
      '\u001b[MK!!',
      '\u001b[MG!!',
      '\u001b[M[!!',
      '\u001b[MO!!',
      '\u001b[M_!!',
    ]);
  });

  test('xterm MouseService 09', () async {
    final terminal = Terminal(
      options: TerminalOptions(
        cols: 500,
        rows: 500,
        mouseEventsRequireAlt: true,
      ),
    );
    addTearDown(terminal.dispose);
    final reports = <String>[];
    terminal.onData.listen(reports.add);
    await terminal.writeAndWait('\u001b[?1003h\u001b[?1006h');
    expect(
      terminal.reportMouseEvent(
        _event(TerminalMouseButton.left, TerminalMouseAction.down, alt: true),
      ),
      isTrue,
    );
    expect(reports, <String>['\u001b[<0;1;1M']);
  });
}

final List<TerminalMouseEvent> _standardEvents = <TerminalMouseEvent>[
  _event(TerminalMouseButton.left, TerminalMouseAction.down),
  _event(TerminalMouseButton.left, TerminalMouseAction.up),
  _event(TerminalMouseButton.left, TerminalMouseAction.move),
  _event(TerminalMouseButton.middle, TerminalMouseAction.down),
  _event(TerminalMouseButton.right, TerminalMouseAction.down),
  _event(TerminalMouseButton.wheel, TerminalMouseAction.up),
  _event(TerminalMouseButton.none, TerminalMouseAction.move),
];

Future<Terminal> _terminalForMode(int mode, {int? encodingMode}) async {
  final terminal = Terminal(options: TerminalOptions(cols: 500, rows: 500));
  addTearDown(terminal.dispose);
  await terminal.writeAndWait(
    '\u001b[?${mode}h${encodingMode == null ? '' : '\u001b[?${encodingMode}h'}',
  );
  return terminal;
}

bool _trigger(
  Terminal terminal,
  TerminalMouseButton button,
  TerminalMouseAction action,
) => terminal.reportMouseEvent(_event(button, action));

bool _triggerAt(Terminal terminal, int column, int row) =>
    terminal.reportMouseEvent(
      TerminalMouseEvent(
        column: column,
        row: row,
        button: TerminalMouseButton.left,
        action: TerminalMouseAction.down,
      ),
    );

TerminalMouseEvent _event(
  TerminalMouseButton button,
  TerminalMouseAction action, {
  bool shift = false,
  bool alt = false,
  bool control = false,
}) => TerminalMouseEvent(
  column: 0,
  row: 0,
  button: button,
  action: action,
  shift: shift,
  alt: alt,
  control: control,
);
