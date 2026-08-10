import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm CharWidth 00', () async {
    await _expectWidth(List<String>.filled(27, '𝄞').join(), 28);
  });

  test('xterm CharWidth 01', () async {
    await _expectWidth('a１２３４５６７８９０', 22);
  });

  test('xterm CharWidth 02', () async {
    await _expectWidth('１２３４５６７８９０', 21);
  });

  test('xterm CharWidth 03', () async {
    await _expectWidth(List<String>.filled(9, 'é').join(), 10);
  });

  test('xterm CharWidth 04', () async {
    await _expectWidth(List<String>.filled(11, '𓂀́').join(), 12);
  });

  test('xterm CharWidth 05', () async {
    await _expectWidth('This is just ASCII text.', 25);
  });
}

Future<void> _expectWidth(String text, int expected) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  await terminal.writeAndWait('$text#');
  final line = terminal.buffer.active.getLine(0)!;
  var width = 0;
  for (var column = 0; column < line.length; column++) {
    final cell = line.getCell(column)!;
    width += cell.width;
    if (cell.chars == '#') break;
  }
  expect(width, expected);
}
