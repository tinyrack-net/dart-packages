import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler OSC 8', () {
    test('8: hyperlink with id', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b]8;id=100;http://localhost:3000\x07link\x1b]8;;\x07',
      );
      final line = terminal.buffer.active.getLine(0)!;
      expect(line.getCell(0)!.hyperlinkId, isNot(0));
      expect(line.getCell(3)!.hyperlinkId, line.getCell(0)!.hyperlinkId);
      expect(line.getCell(4)!.hyperlinkId, 0);
      final links = await terminal.linkProviders.first.provideLinks(1);
      expect(links.single.text, 'http://localhost:3000');
    });

    test('8: hyperlink with semi-colon', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\x1b]8;;http://localhost:3000;abc=def\x07link\x1b]8;;\x07',
      );
      final links = await terminal.linkProviders.first.provideLinks(1);
      expect(links.single.text, 'http://localhost:3000;abc=def');
      expect(terminal.buffer.active.getLine(0)!.getCell(4)!.hyperlinkId, 0);
    });
  });
}
