import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('OscLinkProvider', () {
    test(
      'expands a wrapped link range backward to the previous line',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 5));
        addTearDown(terminal.dispose);

        await terminal.writeAndWait(
          'aa'
          '\u001b]8;;https://example.com/1\u001b\\'
          'bbbcccc'
          '\u001b]8;;\u001b\\'
          'x',
        );

        final links = await terminal.linkProviders.first.provideLinks(2);
        expect(links, hasLength(1));
        expect(
          links.single.range,
          const TerminalBufferRange(
            start: TerminalBufferPosition(3, 1),
            end: TerminalBufferPosition(4, 2),
          ),
        );
      },
    );

    test(
      'expands a wrapped link range forward when a link ends at line boundary',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 5));
        addTearDown(terminal.dispose);

        await terminal.writeAndWait(
          '\u001b]8;;https://example.com/1\u001b\\'
          'aaaaabb'
          '\u001b]8;;\u001b\\'
          'ccc',
        );

        final links = await terminal.linkProviders.first.provideLinks(1);
        expect(links, hasLength(1));
        expect(
          links.single.range,
          const TerminalBufferRange(
            start: TerminalBufferPosition(1, 1),
            end: TerminalBufferPosition(2, 2),
          ),
        );
      },
    );

    test('does not merge wrapped links with different url ids', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 5));
      addTearDown(terminal.dispose);

      await terminal.writeAndWait(
        '\u001b]8;;https://example.com/1\u001b\\'
        'aaaaa'
        '\u001b]8;;\u001b\\'
        '\u001b]8;;https://example.com/2\u001b\\'
        'bbb'
        '\u001b]8;;\u001b\\'
        'cc',
      );

      final links = await terminal.linkProviders.first.provideLinks(1);
      expect(links, hasLength(1));
      expect(
        links.single.range,
        const TerminalBufferRange(
          start: TerminalBufferPosition(1, 1),
          end: TerminalBufferPosition(5, 1),
        ),
      );
    });
  });
}
