import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerCursorPlaywrightCase(String name) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  if (name.contains(' - CUU:')) {
    await terminal.writeAndWait('\n\n\n\n\x1b[Aa\x1b[2Ab');
    return _expectLines(terminal, <String>['', ' b', '', 'a']);
  }
  if (name.contains(' - CUD:')) {
    await terminal.writeAndWait('\x1b[Ba\x1b[2Bb');
    return _expectLines(terminal, <String>['', 'a', '', ' b']);
  }
  if (name.contains(' - CUF:')) {
    await terminal.writeAndWait('\x1b[Ca\x1b[2Cb');
    return _expectLines(terminal, <String>[' a  b']);
  }
  if (name.contains(' - CUB:')) {
    await terminal.writeAndWait('foo\x1b[Da\x1b[2Db');
    return _expectLines(terminal, <String>['fba']);
  }
  if (name.contains(' - CNL:')) {
    await terminal.writeAndWait('\x1b[Ea\x1b[2Eb');
    return _expectLines(terminal, <String>['', 'a', '', 'b']);
  }
  if (name.contains(' - CPL:')) {
    await terminal.writeAndWait('\n\n\n\n\x1b[Fa\x1b[2Fb');
    return _expectLines(terminal, <String>['', 'b', '', 'a', '']);
  }
  if (name.contains(' - CHA:')) {
    await terminal.writeAndWait('foo\x1b[Ga\x1b[10Gb');
    return _expectLines(terminal, <String>['aoo      b']);
  }
  if (name.contains(' - CUP:') || name.contains(' - HVP:')) {
    final finalByte = name.contains(' - CUP:') ? 'H' : 'f';
    await terminal.writeAndWait(
      'foo\x1b[$finalByte'
      'a\x1b[3;3${finalByte}b',
    );
    return _expectLines(terminal, <String>['aoo', '', '  b']);
  }
  if (name.contains(' - HPA:')) {
    await terminal.writeAndWait('foo\x1b[`a\x1b[10`b');
    return _expectLines(terminal, <String>['aoo      b']);
  }
  if (name.contains(' - HPR:')) {
    await terminal.writeAndWait('a\x1b[2aB');
    return _expectLines(terminal, <String>['a  B']);
  }
  if (name.contains(' - VPA:')) {
    await terminal.writeAndWait('\n\n\n   \x1b[da\x1b[2d    b');
    return _expectLines(terminal, <String>['   a', '        b', '', '   ']);
  }
  if (name.contains(' - VPR:')) {
    await terminal.writeAndWait('\x1b[ea\x1b[2eb');
    return _expectLines(terminal, <String>['', 'a', '', ' b']);
  }
  throw StateError('unhandled cursor Playwright case: $name');
}

void _expectLines(Terminal terminal, List<String> expected) {
  expect(
    List<String>.generate(
      expected.length,
      (row) => terminal.buffer.active
          .getLine(row)!
          .translateToString(trimRight: true),
    ),
    expected,
  );
}
