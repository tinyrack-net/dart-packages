import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler SL SR DECIC DECDC', () {
    test('scroll left', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await _fill(terminal);
      await terminal.writeAndWait('\x1b[ @');
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '2345')]);
      await terminal.writeAndWait('\x1b[0 @');
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '345')]);
      await terminal.writeAndWait('\x1b[2 @');
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '5')]);
    });

    test('scroll right', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await _fill(terminal);
      await terminal.writeAndWait('\x1b[ A');
      expect(_lines(terminal), <String>['12345', ...List.filled(5, ' 1234')]);
      await terminal.writeAndWait('\x1b[0 A');
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '  123')]);
      await terminal.writeAndWait('\x1b[2 A');
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '    1')]);
    });

    test('inserts columns', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await _fill(terminal);
      await terminal.writeAndWait("\x1b[3;3H\x1b['}");
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '12 34')]);
      terminal.reset();
      await _fill(terminal);
      await terminal.writeAndWait("\x1b[3;3H\x1b[1'}");
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '12 34')]);
      terminal.reset();
      await _fill(terminal);
      await terminal.writeAndWait("\x1b[3;3H\x1b[2'}");
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '12  3')]);
    });

    test('deletes columns', () async {
      final terminal = _terminal();
      addTearDown(terminal.dispose);
      await _fill(terminal);
      await terminal.writeAndWait("\x1b[3;3H\x1b['~");
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '1245')]);
      terminal.reset();
      await _fill(terminal);
      await terminal.writeAndWait("\x1b[3;3H\x1b[1'~");
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '1245')]);
      terminal.reset();
      await _fill(terminal);
      await terminal.writeAndWait("\x1b[3;3H\x1b[2'~");
      expect(_lines(terminal), <String>['12345', ...List.filled(5, '125')]);
    });

    test(
      "CSI Ps ' } - Insert Ps Column(s) (default = 1) (DECIC), VT420 and up.",
      () async {
        final terminal = _terminal();
        addTearDown(terminal.dispose);
        await _fill(terminal);
        await terminal.writeAndWait("\x1b[3;3H\x1b['}");
        expect(_lines(terminal), <String>['12345', ...List.filled(5, '12 34')]);
      },
    );

    test(
      "CSI Ps ' ~ - Delete Ps Column(s) (default = 1) (DECDC), VT420 and up.",
      () async {
        final terminal = _terminal();
        addTearDown(terminal.dispose);
        await _fill(terminal);
        await terminal.writeAndWait("\x1b[3;3H\x1b['~");
        expect(_lines(terminal), <String>['12345', ...List.filled(5, '1245')]);
      },
    );
  });
}

Terminal _terminal() =>
    Terminal(options: TerminalOptions(cols: 5, rows: 5, scrollback: 1));

Future<void> _fill(Terminal terminal) =>
    terminal.writeAndWait(List<String>.filled(6, '12345').join());

List<String> _lines(Terminal terminal) => <String>[
  for (var row = 0; row < 6; row++)
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true),
];
