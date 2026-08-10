import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler colon notation', () {
    test('CSI 38:2::50:100:150 m', () => _verify(_fixtures[0]));
    test('CSI 38:2::50:100: m', () => _verify(_fixtures[1]));
    test('CSI 38:2::50:: m', () => _verify(_fixtures[2]));
    test('CSI 38:2:::: m', () => _verify(_fixtures[3]));
    test('CSI 38;2::50:100:150 m', () => _verify(_fixtures[4]));
    test('CSI 38;2;50:100:150 m', () => _verify(_fixtures[5]));
    test('CSI 38;2;50;100:150 m', () => _verify(_fixtures[6]));
    test('CSI 38:5:50 m', () => _verify(_fixtures[7]));
    test('CSI 38:5: m', () => _verify(_fixtures[8]));
    test('CSI 38;5:50 m', () => _verify(_fixtures[9]));
    test('CSI 38:2 m', () => _verify(_fixtures[10]));
    test('CSI 38:5 m', () => _verify(_fixtures[11]));
    test('CSI 1 ; 38:2::50:100:150 ; 4 m', () => _verify(_fixtures[12]));
    test('CSI 1 ; 38:2::50:100: ; 4 m', () => _verify(_fixtures[13]));
    test('CSI 1 ; 38:2::50:100 ; 4 m', () => _verify(_fixtures[14]));
    test('CSI 1 ; 38:2:: ; 4 m', () => _verify(_fixtures[15]));
    test('CSI 1 ; 38;2:: ; 4 m', () => _verify(_fixtures[16]));
  });
}

Future<void> _verify(_Fixture fixture) async {
  final expected = await _attributes(fixture.semicolon);
  final actual = await _attributes(fixture.colon);
  expect(actual, expected);
  expect(actual.value, fixture.value);
  expect(actual.bold, fixture.bold);
  expect(actual.underline, fixture.underline);
}

final class _Fixture {
  const _Fixture(
    this.name,
    this.semicolon,
    this.colon,
    this.value, {
    this.bold = false,
    this.underline = false,
  });

  final String name;
  final String semicolon;
  final String colon;
  final int value;
  final bool bold;
  final bool underline;
}

const _fixtures = <_Fixture>[
  _Fixture(
    'CSI 38:2::50:100:150 m',
    '\x1b[38;2;50;100;150m',
    '\x1b[38:2::50:100:150m',
    0x326496,
  ),
  _Fixture(
    'CSI 38:2::50:100: m',
    '\x1b[38;2;50;100;m',
    '\x1b[38:2::50:100:m',
    0x326400,
  ),
  _Fixture('CSI 38:2::50:: m', '\x1b[38;2;50;;m', '\x1b[38:2::50::m', 0x320000),
  _Fixture('CSI 38:2:::: m', '\x1b[38;2;;;m', '\x1b[38:2::::m', 0),
  _Fixture(
    'CSI 38;2::50:100:150 m',
    '\x1b[38;2;50;100;150m',
    '\x1b[38;2::50:100:150m',
    0x326496,
  ),
  _Fixture(
    'CSI 38;2;50:100:150 m',
    '\x1b[38;2;50;100;150m',
    '\x1b[38;2;50:100:150m',
    0x326496,
  ),
  _Fixture(
    'CSI 38;2;50;100:150 m',
    '\x1b[38;2;50;100;150m',
    '\x1b[38;2;50;100:150m',
    0x326496,
  ),
  _Fixture('CSI 38:5:50 m', '\x1b[38;5;50m', '\x1b[38:5:50m', 50),
  _Fixture('CSI 38:5: m', '\x1b[38;5;m', '\x1b[38:5:m', 0),
  _Fixture('CSI 38;5:50 m', '\x1b[38;5;50m', '\x1b[38;5:50m', 50),
  _Fixture('CSI 38:2 m', '\x1b[38;2m', '\x1b[38:2m', 0),
  _Fixture('CSI 38:5 m', '\x1b[38;5m', '\x1b[38:5m', 0),
  _Fixture(
    'CSI 1 ; 38:2::50:100:150 ; 4 m',
    '\x1b[1;38;2;50;100;150;4m',
    '\x1b[1;38:2::50:100:150;4m',
    0x326496,
    bold: true,
    underline: true,
  ),
  _Fixture(
    'CSI 1 ; 38:2::50:100: ; 4 m',
    '\x1b[1;38;2;50;100;;4m',
    '\x1b[1;38:2::50:100:;4m',
    0x326400,
    bold: true,
    underline: true,
  ),
  _Fixture(
    'CSI 1 ; 38:2::50:100 ; 4 m',
    '\x1b[1;38;2;50;100;;4m',
    '\x1b[1;38:2::50:100;4m',
    0x326400,
    bold: true,
    underline: true,
  ),
  _Fixture(
    'CSI 1 ; 38:2:: ; 4 m',
    '\x1b[1;38;2;;;;4m',
    '\x1b[1;38:2::;4m',
    0,
    bold: true,
    underline: true,
  ),
  _Fixture(
    'CSI 1 ; 38;2:: ; 4 m',
    '\x1b[1;38;2;;;;4m',
    '\x1b[1;38;2::;4m',
    0,
    bold: true,
    underline: true,
  ),
];

Future<({TerminalColorMode mode, int value, bool bold, bool underline})>
_attributes(String sequence) async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('${sequence}X');
    final cell = terminal.buffer.active.getLine(0)!.getCell(0)!;
    return (
      mode: cell.foregroundMode,
      value: cell.foreground,
      bold: cell.isBold,
      underline: cell.isUnderline,
    );
  } finally {
    terminal.dispose();
  }
}
