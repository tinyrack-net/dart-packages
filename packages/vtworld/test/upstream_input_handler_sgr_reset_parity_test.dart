import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler reset text attributes', () {
    test('resets all attributes if there is no url', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\x1b[30;40;4m\x1b[mX');
      final cell = terminal.buffer.active.getLine(0)!.getCell(0)!;
      expect(cell.isForegroundDefault, isTrue);
      expect(cell.isBackgroundDefault, isTrue);
      expect(cell.isUnderline, isFalse);
      expect(cell.hyperlinkId, 0);
    });

    test('resets all attributes except for the url', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b[30;40;4m'
        '\x1b]8;;http://example.com\x1b\\'
        '\x1b[mX'
        '\x1b]8;;\x1b\\',
      );
      final cell = terminal.buffer.active.getLine(0)!.getCell(0)!;
      expect(cell.isForegroundDefault, isTrue);
      expect(cell.isBackgroundDefault, isTrue);
      expect(cell.isUnderline, isFalse);
      expect(cell.hyperlinkId, isNot(0));
      final links = await terminal.linkProviders.first.provideLinks(1);
      expect(links.single.text, 'http://example.com');
    });
  });
}
