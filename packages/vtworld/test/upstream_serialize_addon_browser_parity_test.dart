import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm SerializeAddon playwright 0', () async {
    expect(await _roundTrip(_bceScrollInput()), isTrue);
  });

  test('xterm SerializeAddon playwright 1', () async {
    final setup = _setup(scrollback: 10);
    final lines = List<String>.generate(20, (index) => _digits(10, index));
    await setup.terminal.writeAndWait(lines.join('\r\n'));
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(scrollback: 5),
      ),
      lines.sublist(5).join('\r\n'),
    );
  });

  test('xterm SerializeAddon playwright 2', () async {
    await _expectSerialization(
      const ['a\tb', 'aa\tc', 'aaa\td'].join('\r\n'),
      const ['a\u001b[7Cb', 'aa\u001b[6Cc', 'aaa\u001b[5Cd'].join('\r\n'),
    );
  });

  test('xterm SerializeAddon playwright 3', () async {
    await _expectStyleLines(_color16Together());
  });

  test('xterm SerializeAddon playwright 4', () async {
    await _expectMode('\u001b[?9h', '\u001b[?9l');
    await _expectMode('\u001b[?1000h', '\u001b[?1000l');
    await _expectMode('\u001b[?1002h', '\u001b[?1002l');
    await _expectMode('\u001b[?1003h', '\u001b[?1003l');
  });

  test('xterm SerializeAddon playwright 5', () async {
    final lines = <String>[
      '',
      '',
      _digits(10),
      _digits(10),
      '',
      '',
      _digits(10),
      _digits(10),
      '',
      '',
      '',
    ];
    await _expectSerialization(lines.join('\r\n'), lines.join('\r\n'));
  });

  test('xterm SerializeAddon playwright 6', () async {
    expect(await _roundTrip('1\u001b[44m\u001b[5X\r\n2\u001b[9X'), isTrue);
  });

  test('xterm SerializeAddon playwright 7', () async {
    await _expectMode('\u001b[?1h', '\u001b[?1l');
  });

  test('xterm SerializeAddon playwright 8', () async {
    await _expectStyleLines(_flagLines());
  });

  test('xterm SerializeAddon playwright 9', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('before\u001b[?1hafter');
    expect(setup.addon.serialize(), 'beforeafter\u001b[?1h');
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(excludeModes: true),
      ),
      'beforeafter',
    );
  });

  test('xterm SerializeAddon playwright 10', () async {
    await _expectSerialization('中文\t12', '中文\u001b[4C12');
  });

  test('xterm SerializeAddon playwright 11', () async {
    await _expectStyleLines(_rgbSeparate());
  });

  test('xterm SerializeAddon playwright 12', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(
      '\u001b[4:2;58:5:196mA\u001b[4:2;58:5:196mB',
    );
    var line = setup.terminal.buffer.active.getLine(0)!;
    expect(line.getCell(0)!.attributesEqual(line.getCell(1)!), isTrue);
    setup.terminal.reset();
    await setup.terminal.writeAndWait(
      '\u001b[4:2;58:5:196mA\u001b[4:2;58:5:46mB',
    );
    line = setup.terminal.buffer.active.getLine(0)!;
    expect(line.getCell(0)!.attributesEqual(line.getCell(1)!), isFalse);
  });

  test('xterm SerializeAddon playwright 13', () async {
    await _expectStyleLines(_paletteSeparate());
  });

  test('xterm SerializeAddon playwright 14', () async {
    await _expectStyleLines(_color16Separate());
  });

  test('xterm SerializeAddon playwright 15', () async {
    await _expectSerialization(
      '1\u001b[?1049h\u001b[H2',
      '1\u001b[?1049h\u001b[H2',
    );
  });

  test('xterm SerializeAddon playwright 16', () async {
    await _expectSerialization('', '');
  });

  test('xterm SerializeAddon playwright 17', () async {
    final setup = _setup(scrollback: 10);
    final lines = List<String>.generate(20, (index) => _digits(10, index));
    await setup.terminal.writeAndWait(lines.join('\r\n'));
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(scrollback: 0),
      ),
      lines.sublist(10).join('\r\n'),
    );
  });

  test('xterm SerializeAddon playwright 18', () async {
    final lines = List<String>.filled(10, _digits(10));
    await _expectSerialization(lines.join('\r\n'), lines.join('\r\n'));
  });

  test('xterm SerializeAddon playwright 19', () async {
    await _expectStyleLines([
      '\u001b[53m++++++++++',
      '\u001b[4m++++++++++',
      '\u001b[0m++++++++++',
    ]);
  });

  test('xterm SerializeAddon playwright 20', () async {
    await _expectMode('\u001b[?66h', '\u001b[?66l');
  });

  test('xterm SerializeAddon playwright 21', () async {
    await _expectMode('\u001b[4h', '\u001b[4l');
  });

  test('xterm SerializeAddon playwright 22', () async {
    await _expectMode('\u001b[?1004h', '\u001b[?1004l');
  });

  test('xterm SerializeAddon playwright 23', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('test\u001b[?6h');
    expect(setup.addon.serialize(), 'test\u001b[4D\u001b[?6h');
    await setup.terminal.writeAndWait('\u001b[?6l');
    expect(setup.addon.serialize(), 'test\u001b[4D');
  });

  test('xterm SerializeAddon playwright 24', () async {
    final lines = List<String>.generate(
      32,
      (index) => '\u001b[38;5;${16 + index}m${_digits(10, index)}',
    );
    await _expectStyleLines(lines);
  });

  test('xterm SerializeAddon playwright 25', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('normal\u001b[?1049h\u001b[Halt');
    expect(setup.addon.serialize(), 'normal\u001b[?1049h\u001b[Halt');
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(excludeAltBuffer: true),
      ),
      'normal',
    );
  });

  test('xterm SerializeAddon playwright 26', () async {
    expect(await _roundTrip(_invalidWrapInput()), isTrue);
  });

  test('xterm SerializeAddon playwright 27', () async {
    expect(
      await _snapshotFor('1234567890\r\n12345'),
      isNot(await _snapshotFor('123456789012345')),
    );
  });

  test('xterm SerializeAddon playwright 28', () async {
    await _expectMode('\u001b[?2004h', '\u001b[?2004l');
  });

  test('xterm SerializeAddon playwright 29', () async {
    await _expectStyleLines(_rgbTogether());
  });

  test('xterm SerializeAddon playwright 30', () async {
    await _expectSerialization('1\u001b[?1049h2\u001b[?1049l', '1');
  });

  test('xterm SerializeAddon playwright 31', () async {
    await _expectMode('\u001b[?45h', '\u001b[?45l');
  });

  test('xterm SerializeAddon playwright 32', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('test\u001b[?7l');
    expect(setup.addon.serialize(), 'test\u001b[?7l');
    await setup.terminal.writeAndWait('\u001b[?7h');
    expect(setup.addon.serialize(), 'test');
  });

  test('xterm SerializeAddon playwright 33', () async {
    expect(await _snapshotFor('12345'), isNot(await _snapshotFor('67890')));
  });

  test('xterm SerializeAddon playwright 34', () async {
    final lines = ['中文中文', '12中文', '中文12', '1中文中文中'];
    await _expectSerialization(lines.join('\r\n'), lines.join('\r\n'));
  });

  test('xterm SerializeAddon playwright 35', () async {
    final padding = List<String>.generate(
      10,
      (index) => _digits(10, index),
    ).join('\r\n');
    expect(await _roundTrip('$padding\r\n${_invalidWrapInput()}'), isTrue);
  });

  test('xterm SerializeAddon playwright 36', () async {
    await _expectSerialization('123456789123456789', '123456789123456789');
  });

  test('xterm SerializeAddon playwright 37', () async {
    await _expectSerialization(
      '123456789\r\n123456789',
      '123456789\r\n123456789',
    );
  });

  test('xterm SerializeAddon playwright 38', () async {
    await _expectStyleLines(_paletteTogether());
  });

  test('xterm SerializeAddon playwright 39', () async {
    const colors = <int>[
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      90,
      91,
      92,
      93,
      94,
      95,
      96,
      97,
      40,
      41,
      42,
      43,
      44,
      45,
      46,
      47,
      100,
      101,
      103,
      104,
      105,
      106,
      107,
    ];
    final lines = List<String>.generate(
      colors.length,
      (i) => '\u001b[${colors[i]}m${_digits(10, i)}',
    );
    await _expectStyleLines(lines);
  });
}

Future<void> _expectSerialization(String input, String expected) async {
  final setup = _setup(scrollback: 40);
  await setup.terminal.writeAndWait(input);
  expect(setup.addon.serialize(), expected);
}

Future<void> _expectStyleLines(List<String> lines) =>
    _expectSerialization(lines.join('\r\n'), lines.join('\r\n'));

Future<void> _expectMode(String enable, String disable) async {
  final setup = _setup();
  await setup.terminal.writeAndWait('test$enable');
  expect(setup.addon.serialize(), 'test$enable');
  await setup.terminal.writeAndWait(disable);
  expect(setup.addon.serialize(), 'test');
}

Future<bool> _roundTrip(String input) async {
  final first = _setup(scrollback: 40);
  await first.terminal.writeAndWait(input);
  final before = _snapshot(first.terminal.buffer.normal);
  final second = _setup(scrollback: 40);
  await second.terminal.writeAndWait(first.addon.serialize());
  return before == _snapshot(second.terminal.buffer.normal);
}

Future<String> _snapshotFor(String input) async {
  final setup = _setup();
  await setup.terminal.writeAndWait(input);
  return _snapshot(setup.terminal.buffer.normal);
}

String _snapshot(TerminalBuffer buffer) => <String>[
  '${buffer.cursorX}:${buffer.cursorY}:${buffer.baseY}',
  for (var row = 0; row < buffer.length; row++)
    _snapshotLine(buffer.getLine(row)!),
].join('|');

String _snapshotLine(TerminalBufferLine line) =>
    '${line.isWrapped}:${line.translateToString()}';

String _digits(int length, [int from = 0]) =>
    List<String>.generate(length, (index) => '${(from + index) % 10}').join();

String _invalidWrapInput() =>
    '123456789012345\u001b[1A\u001b[5X\u001b[1B\u001b[5D\u001b[5X\u001b[1A1';

String _bceScrollInput() =>
    '${List<String>.generate(10, (i) => _digits(10, i)).join('\r\n')}\r\n'
    '\u001b[44m\u001b[5X1111111111111111';

String _sgr(List<String> values) => '\u001b[${values.join(';')}m';

List<String> _flagLines() => <String>[
  '${_sgr(['32'])}++++++++++',
  '${_sgr(['7'])}++++++++++',
  '${_sgr(['1'])}++++++++++',
  '${_sgr(['4'])}++++++++++',
  '${_sgr(['5'])}++++++++++',
  '${_sgr(['8'])}++++++++++',
  '${_sgr(['9'])}++++++++++',
  '${_sgr(['27'])}++++++++++',
  '${_sgr(['22'])}++++++++++',
  '${_sgr(['24'])}++++++++++',
  '${_sgr(['25'])}++++++++++',
  '${_sgr(['28'])}++++++++++',
  '${_sgr(['29'])}++++++++++',
];

List<String> _styleSequence(String red, String green, String yellow) =>
    <String>[
      '${_sgr([red])}++++++++++',
      '${_sgr(['4'])}++++++++++',
      '${_sgr([green])}++++++++++',
      '${_sgr(['7'])}++++++++++',
      '${_sgr(['27'])}++++++++++',
      '${_sgr(['7'])}++++++++++',
      '${_sgr([yellow])}++++++++++',
      '${_sgr(['39'])}++++++++++',
      '${_sgr(['49'])}++++++++++',
      '${_sgr(['0'])}++++++++++',
    ];

List<String> _styleTogether(String red, String green, String yellow) {
  final once = <String>[
    '${_sgr([red])}++++++++++',
    '${_sgr([green, yellow])}++++++++++',
    '${_sgr(['4', '3'])}++++++++++',
    '${_sgr(['24', '23'])}++++++++++',
    '${_sgr(['39', '3'])}++++++++++',
    '${_sgr(['49'])}++++++++++',
    '${_sgr(['0'])}++++++++++',
  ];
  return <String>[...once, ...once.take(6)];
}

List<String> _color16Separate() => _styleSequence('31', '32', '43');
List<String> _paletteSeparate() =>
    _styleSequence('38;5;196', '38;5;46', '48;5;226');
List<String> _rgbSeparate() =>
    _styleSequence('38;2;255;0;0', '38;2;0;255;0', '48;2;255;255;0');
List<String> _color16Together() => _styleTogether('31', '32', '43');
List<String> _paletteTogether() =>
    _styleTogether('38;5;196', '38;5;46', '48;5;226');
List<String> _rgbTogether() =>
    _styleTogether('38;2;255;0;0', '38;2;0;255;0', '48;2;255;255;0');

({Terminal terminal, SerializeAddon addon}) _setup({int scrollback = 1000}) {
  final terminal = Terminal(
    options: TerminalOptions(cols: 10, rows: 10, scrollback: scrollback),
  );
  final addon = SerializeAddon();
  terminal.loadAddon(addon);
  addTearDown(terminal.dispose);
  return (terminal: terminal, addon: addon);
}
