import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler Kitty keyboard', () {
    test('should evict oldest entry when stack exceeds 16 entries', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);

      await terminal.writeAndWait('${_pushes(20)}\x1b[<15u\x1b[?u');

      expect(reports, <String>['\x1b[?5u']);
    });

    test('should maintain separate flags for main and alt screens', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);

      await terminal.writeAndWait(
        '\x1b[>5u\x1b[?u'
        '\x1b[?1049h\x1b[?u'
        '\x1b[>7u\x1b[?u'
        '\x1b[?1049l\x1b[?u'
        '\x1b[?1049h\x1b[?u',
      );

      expect(reports, <String>[
        '\x1b[?5u',
        '\x1b[?0u',
        '\x1b[?7u',
        '\x1b[?5u',
        '\x1b[?7u',
      ]);
    });

    test('should reset flags to 0 when stack is emptied', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);

      await terminal.writeAndWait('\x1b[>5u\x1b[<10u\x1b[?u');

      expect(reports, <String>['\x1b[?0u']);
    });
  });
}

Terminal _terminal() => Terminal(
  options: TerminalOptions(
    vtExtensions: const TerminalVtExtensions(kittyKeyboard: true),
  ),
);

String _pushes(int count) => <String>[
  for (var value = 1; value <= count; value++) '\x1b[>${value}u',
].join();
