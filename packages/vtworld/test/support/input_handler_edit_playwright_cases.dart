import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerEditPlaywrightCase(String name) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  if (name.contains(' - ICH:')) {
    await terminal.writeAndWait('foo\x1b[3D\x1b[@\n\rbar\x1b[3D\x1b[4@');
    return _expectLines(terminal, <String>[' foo', '    bar']);
  }
  if (name.contains(' - SL:')) {
    await terminal.writeAndWait('abcdefg\x1b[ @');
    _expectLines(terminal, <String>['bcdefg']);
    terminal.reset();
    await terminal.writeAndWait('abcdefg\x1b[3 @');
    return _expectLines(terminal, <String>['defg']);
  }
  if (name.contains(' - CHT:')) {
    await terminal.writeAndWait('\x1b[Ia\n\r\x1b[2Ib');
    return _expectLines(terminal, <String>['        a', '                b']);
  }
  if (name.contains(' - ED:') || name.contains(' - DECSED:')) {
    return _eraseDisplay(terminal, private: name.contains(' - DECSED:'));
  }
  if (name.contains(' - EL:') || name.contains(' - DECSEL:')) {
    return _eraseLine(terminal, private: name.contains(' - DECSEL:'));
  }
  if (name.contains(' - IL:')) {
    await terminal.writeAndWait('foo\x1b[La\x1b[2Lb');
    return _expectLines(terminal, <String>['b', '', 'a', 'foo']);
  }
  if (name.contains(' - DL:')) {
    await terminal.writeAndWait(
      'a\nb\x1b[1F\x1b[M\x1b[1Ed\ne\nf\x1b[2F\x1b[2M',
    );
    return _expectLines(terminal, <String>[' b', '  f', '', '', '']);
  }
  if (name.contains(' - DCH:')) {
    await terminal.writeAndWait('abc\x1b[1;1H\x1b[P\n\rdef\x1b[2;1H\x1b[2P');
    return _expectLines(terminal, <String>['bc', 'f']);
  }
  if (name.contains(' - SU:')) return _scroll(terminal, finalByte: 'S');
  if (name.contains(' - SD:')) {
    return _scroll(terminal, finalByte: name.contains('Ps ^') ? '^' : 'T');
  }
  if (name.contains(' - ECH:')) {
    await terminal.writeAndWait('abcdef\x1b[1;1H\x1b[X');
    _expectLines(terminal, <String>[' bcdef']);
    terminal.reset();
    await terminal.writeAndWait('abcdef\x1b[1;1H\x1b[3X');
    return _expectLines(terminal, <String>['   def']);
  }
  if (name.contains(' - CBT:')) {
    await terminal.writeAndWait('\x1b[17Ga\x1b[17G\x1b[Zb');
    return _expectLines(terminal, <String>['        b       a']);
  }
  if (name.contains(' - REP:')) return _repeat(terminal);
  if (name.contains(' - TBC:')) return _tabClear(terminal);
  throw StateError('unhandled editing Playwright case: $name');
}

Future<void> _eraseDisplay(Terminal terminal, {required bool private}) async {
  terminal.resize(5, 5);
  const fixture = 'abc\n\rdef\n\rghi\x1b[2;2H';
  final prefix = private ? '?' : '';
  await terminal.writeAndWait(
    '$fixture\x1b[$prefix'
    'J',
  );
  _expectLines(terminal, <String>['abc', 'd', '']);
  terminal.reset();
  await terminal.writeAndWait('$fixture\x1b[${prefix}0J');
  _expectLines(terminal, <String>['abc', 'd', '']);
  terminal.reset();
  await terminal.writeAndWait('$fixture\x1b[${prefix}1J');
  _expectLines(terminal, <String>['', '  f', 'ghi']);
  terminal.reset();
  await terminal.writeAndWait('1\n2\n3\n4\n5$fixture\x1b[${prefix}3J');
  expect(terminal.buffer.active.length, 5);
  _expectLines(terminal, <String>['   4', '    5', 'abc', 'def', 'ghi']);
}

Future<void> _eraseLine(Terminal terminal, {required bool private}) async {
  const fixture = 'abcde\x1b[1;3H';
  final prefix = private ? '?' : '';
  await terminal.writeAndWait(
    '$fixture\x1b[$prefix'
    'K',
  );
  _expectLines(terminal, <String>['ab']);
  terminal.reset();
  await terminal.writeAndWait('$fixture\x1b[${prefix}0K');
  _expectLines(terminal, <String>['ab']);
  terminal.reset();
  await terminal.writeAndWait('$fixture\x1b[${prefix}1K');
  _expectLines(terminal, <String>['   de']);
  terminal.reset();
  await terminal.writeAndWait('$fixture\x1b[${prefix}2K');
  _expectLines(terminal, <String>['']);
}

Future<void> _scroll(Terminal terminal, {required String finalByte}) async {
  terminal.resize(80, 5);
  final up = finalByte == 'S';
  await terminal.writeAndWait('1\r\n2\r\n3\r\n4\r\n5\x1b[$finalByte');
  _expectLines(
    terminal,
    up ? <String>['2', '3', '4', '5', ''] : <String>['', '1', '2', '3', '4'],
  );
  terminal.reset();
  await terminal.writeAndWait('1\r\n2\r\n3\r\n4\r\n5\x1b[2$finalByte');
  _expectLines(
    terminal,
    up ? <String>['3', '4', '5', '', ''] : <String>['', '', '1', '2', '3'],
  );
}

Future<void> _repeat(Terminal terminal) async {
  terminal.resize(10, 10);
  await terminal.writeAndWait('#\x1b[b\r\n#\x1b[0b\r\n#\x1b[1b\r\n#\x1b[5b');
  _expectLines(terminal, <String>['##', '##', '##', '######']);
  expect(
    (terminal.buffer.active.cursorX, terminal.buffer.active.cursorY),
    (6, 3),
  );
  terminal.reset();
  await terminal.writeAndWait('￥\x1b[8b');
  _expectLines(terminal, <String>['￥￥￥￥￥']);
  terminal.reset();
  await terminal.writeAndWait('e\u0301\x1b[2b');
  _expectLines(terminal, <String>['e\u0301e\u0301e\u0301']);
  terminal.reset();
  await terminal.writeAndWait('#\x1b[15b');
  _expectLines(terminal, <String>['##########', '######']);
  terminal.reset();
  await terminal.writeAndWait('\x1b[?7l#\x1b[15b');
  _expectLines(terminal, <String>['##########', '']);
  terminal.reset();
  await terminal.writeAndWait(
    '\x1b[?7h#\n\x1b[3b#\r\x1b[3b\r\n'
    'abcdefg\x1b[3D\x1b[10b#\x1b[3b',
  );
  _expectLines(terminal, <String>['#', ' #', 'abcd####']);
}

Future<void> _tabClear(Terminal terminal) async {
  await terminal.writeAndWait('\x1b[9G\x1b[g\x1b[1G\ta');
  _expectLines(terminal, <String>['                a']);
  terminal.reset();
  await terminal.writeAndWait('\x1b[3g\ta');
  _expectLines(terminal, <String>['${' ' * 79}a']);
}

void _expectLines(Terminal terminal, List<String> expected) {
  expect(
    List<String>.generate(
      expected.length,
      (row) => terminal.buffer.active
          .getLine(terminal.buffer.active.baseY + row)!
          .translateToString(trimRight: true),
    ),
    expected,
  );
}
